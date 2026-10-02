import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Available ambient focus sound modes.
enum AmbientSound {
  none(
    id: 'none',
    label: 'None',
    subtitle: 'Silent focus',
    icon: '🔇',
  ),
  rain(
    id: 'rain',
    label: 'Rain',
    subtitle: 'Gentle downpour',
    icon: '🌧️',
  ),
  cozyCafe(
    id: 'cozy_cafe',
    label: 'Cozy Cafe',
    subtitle: 'Warm coffee shop',
    icon: '☕',
  ),
  whiteNoise(
    id: 'white_noise',
    label: 'White Noise',
    subtitle: 'Constant soothing haze',
    icon: '🌊',
  ),
  deepSpaceLoFi(
    id: 'deep_space_lofi',
    label: 'Deep Space Lo-Fi',
    subtitle: '432Hz ambient drone',
    icon: '🪐',
  );

  final String id;
  final String label;
  final String subtitle;
  final String icon;

  const AmbientSound({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

/// Service providing procedural ambient focus audio loops and mechanical ticking sounds.
class AmbientAudioService {
  static final AmbientAudioService _instance = AmbientAudioService._internal();
  factory AmbientAudioService() => _instance;
  AmbientAudioService._internal();

  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _chimePlayer = AudioPlayer();

  final Map<String, String> _cachedSoundFiles = {};
  bool _isInitialized = false;

  AmbientSound _currentSound = AmbientSound.none;
  double _volume = 0.65;
  bool _isTickingEnabled = false;

  AmbientSound get currentSound => _currentSound;
  double get volume => _volume;
  bool get isTickingEnabled => _isTickingEnabled;

  final ValueNotifier<AmbientSound> activeSoundNotifier =
      ValueNotifier<AmbientSound>(AmbientSound.none);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.65);
  final ValueNotifier<bool> tickingNotifier = ValueNotifier<bool>(false);

  /// Initializes audio players and pre-generates audio loops into cache.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.setVolume(_volume);

      await _tickPlayer.setReleaseMode(ReleaseMode.loop);
      await _tickPlayer.setVolume(0.35);

      await _chimePlayer.setReleaseMode(ReleaseMode.stop);
      await _chimePlayer.setVolume(0.8);

      _isInitialized = true;
    } catch (e) {
      debugPrint('AmbientAudioService init error: $e');
    }
  }

  /// Sets the ambient sound loop.
  Future<void> setAmbientSound(AmbientSound sound) async {
    _currentSound = sound;
    activeSoundNotifier.value = sound;

    if (sound == AmbientSound.none) {
      await _ambientPlayer.stop();
      return;
    }

    try {
      final filePath = await _getOrCreateSoundFile(sound);
      if (filePath != null) {
        await _ambientPlayer.stop();
        await _ambientPlayer.setSource(DeviceFileSource(filePath));
        await _ambientPlayer.setVolume(_volume);
        await _ambientPlayer.resume();
      }
    } catch (e) {
      debugPrint('Error playing ambient sound $sound: $e');
    }
  }

  /// Sets ambient audio volume between 0.0 and 1.0.
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    volumeNotifier.value = _volume;
    try {
      await _ambientPlayer.setVolume(_volume);
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  /// Toggles clock ticking sound.
  Future<void> setTickingEnabled(bool enabled) async {
    _isTickingEnabled = enabled;
    tickingNotifier.value = enabled;

    if (!enabled) {
      await _tickPlayer.stop();
      return;
    }

    try {
      final filePath = await _getOrCreateTickFile();
      if (filePath != null) {
        await _tickPlayer.stop();
        await _tickPlayer.setSource(DeviceFileSource(filePath));
        await _tickPlayer.setVolume(0.4);
        await _tickPlayer.resume();
      }
    } catch (e) {
      debugPrint('Error playing ticking sound: $e');
    }
  }

  /// Plays a warm completion chime for when intervals complete.
  Future<void> playCompletionChime() async {
    try {
      final filePath = await _getOrCreateChimeFile();
      if (filePath != null) {
        await _chimePlayer.stop();
        await _chimePlayer.setSource(DeviceFileSource(filePath));
        await _chimePlayer.setVolume(0.85);
        await _chimePlayer.resume();
      }
    } catch (e) {
      debugPrint('Error playing completion chime: $e');
    }
  }

  /// Pauses all ambient and ticking sounds.
  Future<void> pauseAll() async {
    try {
      await _ambientPlayer.pause();
      await _tickPlayer.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  /// Resumes active ambient and ticking sounds.
  Future<void> resumeAll() async {
    try {
      if (_currentSound != AmbientSound.none) {
        await _ambientPlayer.resume();
      }
      if (_isTickingEnabled) {
        await _tickPlayer.resume();
      }
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  /// Stops all audio playback.
  Future<void> stopAll() async {
    try {
      await _ambientPlayer.stop();
      await _tickPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Disposes audio player resources.
  Future<void> dispose() async {
    await stopAll();
    await _ambientPlayer.dispose();
    await _tickPlayer.dispose();
    await _chimePlayer.dispose();
    _isInitialized = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Procedural Sound Synthesizers (WAV format generation)
  // ──────────────────────────────────────────────────────────────────────────

  Future<String?> _getOrCreateSoundFile(AmbientSound sound) async {
    if (_cachedSoundFiles.containsKey(sound.id)) {
      final path = _cachedSoundFiles[sound.id]!;
      if (await File(path).exists()) return path;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ambient_${sound.id}.wav');

      Uint8List bytes;
      switch (sound) {
        case AmbientSound.rain:
          bytes = _generateRainWav(seconds: 8);
          break;
        case AmbientSound.cozyCafe:
          bytes = _generateCozyCafeWav(seconds: 8);
          break;
        case AmbientSound.whiteNoise:
          bytes = _generateWhiteNoiseWav(seconds: 6);
          break;
        case AmbientSound.deepSpaceLoFi:
          bytes = _generateDeepSpaceLoFiWav(seconds: 8);
          break;
        case AmbientSound.none:
          return null;
      }

      await file.writeAsBytes(bytes, flush: true);
      _cachedSoundFiles[sound.id] = file.path;
      return file.path;
    } catch (e) {
      debugPrint('Failed to generate sound file for $sound: $e');
      return null;
    }
  }

  Future<String?> _getOrCreateTickFile() async {
    if (_cachedSoundFiles.containsKey('tick')) {
      final path = _cachedSoundFiles['tick']!;
      if (await File(path).exists()) return path;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ambient_tick.wav');
      final bytes = _generateClockTickWav(seconds: 4);
      await file.writeAsBytes(bytes, flush: true);
      _cachedSoundFiles['tick'] = file.path;
      return file.path;
    } catch (e) {
      debugPrint('Failed to generate tick file: $e');
      return null;
    }
  }

  Future<String?> _getOrCreateChimeFile() async {
    if (_cachedSoundFiles.containsKey('chime')) {
      final path = _cachedSoundFiles['chime']!;
      if (await File(path).exists()) return path;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ambient_chime.wav');
      final bytes = _generateMeditationChimeWav(seconds: 3);
      await file.writeAsBytes(bytes, flush: true);
      _cachedSoundFiles['chime'] = file.path;
      return file.path;
    } catch (e) {
      debugPrint('Failed to generate chime file: $e');
      return null;
    }
  }

  /// Builds a 16-bit mono PCM WAV byte array with a valid RIFF header.
  static Uint8List _buildWavBytes({
    required List<double> samples,
    required int sampleRate,
  }) {
    final numSamples = samples.length;
    final byteRate = sampleRate * 2;
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt subchunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    buffer.setUint16(22, 1, Endian.little); // NumChannels (1 = Mono)
    buffer.setUint32(24, sampleRate, Endian.little); // SampleRate
    buffer.setUint32(28, byteRate, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little); // BlockAlign (2 bytes)
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

    // data subchunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    var offset = 44;
    for (var i = 0; i < numSamples; i++) {
      final sample = samples[i].clamp(-1.0, 1.0);
      final intSample = (sample * 32767.0).round().clamp(-32768, 32767);
      buffer.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  /// 🌧️ Rain Sound: Filtered pink noise + randomized subtle raindrop transients.
  static Uint8List _generateRainWav({int seconds = 8, int sampleRate = 22050}) {
    final totalSamples = seconds * sampleRate;
    final samples = List<double>.filled(totalSamples, 0.0);
    final random = Random(42);

    // Pink noise filter state (Paul Kellet filter)
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, b3 = 0.0, b4 = 0.0, b5 = 0.0, b6 = 0.0;

    for (var i = 0; i < totalSamples; i++) {
      final white = (random.nextDouble() * 2.0 - 1.0);
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      final pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.12;
      b6 = white * 0.115926;

      // Occasional gentle raindrop impact transients
      var drip = 0.0;
      if (random.nextDouble() < 0.0035) {
        final dripFreq = 800.0 + random.nextDouble() * 1200.0;
        final dripLen = (sampleRate * 0.018).toInt();
        for (var j = 0; j < dripLen && (i + j) < totalSamples; j++) {
          final t = j / sampleRate;
          final env = exp(-t * 220.0);
          samples[i + j] += sin(2 * pi * dripFreq * t) * env * 0.18;
        }
      }

      samples[i] += pink + drip;
    }

    _applySeamlessCrossfade(samples, sampleRate: sampleRate);
    return _buildWavBytes(samples: samples, sampleRate: sampleRate);
  }

  /// ☕ Cozy Cafe: Mellow acoustic drone + soft coffee shop crackle and warm resonance.
  static Uint8List _generateCozyCafeWav({int seconds = 8, int sampleRate = 22050}) {
    final totalSamples = seconds * sampleRate;
    final samples = List<double>.filled(totalSamples, 0.0);
    final random = Random(101);

    var filterState = 0.0;
    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      // Soft background murmuring drone frequencies
      final drone1 = sin(2 * pi * 130.0 * t) * 0.06;
      final drone2 = sin(2 * pi * 196.0 * t) * 0.04;
      final drone3 = sin(2 * pi * 261.63 * t) * 0.03;

      // Gentle vinyl/espresso machine hiss & crackle
      final rawNoise = random.nextDouble() * 2.0 - 1.0;
      filterState = filterState * 0.88 + rawNoise * 0.12;
      var crackle = 0.0;
      if (random.nextDouble() < 0.0018) {
        crackle = (random.nextDouble() * 2.0 - 1.0) * 0.22;
      }

      samples[i] = drone1 + drone2 + drone3 + (filterState * 0.15) + crackle;
    }

    _applySeamlessCrossfade(samples, sampleRate: sampleRate);
    return _buildWavBytes(samples: samples, sampleRate: sampleRate);
  }

  /// 🌊 White Noise: Smooth Gaussian noise with soft high-cut filter.
  static Uint8List _generateWhiteNoiseWav({int seconds = 6, int sampleRate = 22050}) {
    final totalSamples = seconds * sampleRate;
    final samples = List<double>.filled(totalSamples, 0.0);
    final random = Random(777);

    var lpf = 0.0;
    for (var i = 0; i < totalSamples; i++) {
      // Approximate Gaussian noise via central limit theorem
      final g = (random.nextDouble() +
              random.nextDouble() +
              random.nextDouble() +
              random.nextDouble() -
              2.0) *
          0.5;

      lpf = lpf * 0.65 + g * 0.35;
      samples[i] = lpf * 0.35;
    }

    _applySeamlessCrossfade(samples, sampleRate: sampleRate);
    return _buildWavBytes(samples: samples, sampleRate: sampleRate);
  }

  /// 🪐 Deep Space Lo-Fi: 432Hz binaural harmonic drone with slow sub-bass sweep.
  static Uint8List _generateDeepSpaceLoFiWav({int seconds = 8, int sampleRate = 22050}) {
    final totalSamples = seconds * sampleRate;
    final samples = List<double>.filled(totalSamples, 0.0);

    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      // 432Hz fundamental & 108Hz sub-bass
      final sub = sin(2 * pi * 108.0 * t) * 0.22;
      final fundamental = sin(2 * pi * 216.0 * t) * 0.18;
      final harmonic = sin(2 * pi * 432.0 * t) * 0.08;

      // Slow breathing LFO envelope (0.2 Hz)
      final lfo = (sin(2 * pi * 0.25 * t) + 1.0) * 0.5;
      final shimmer = sin(2 * pi * 648.0 * t) * (0.02 * lfo);

      samples[i] = sub + fundamental + harmonic + shimmer;
    }

    _applySeamlessCrossfade(samples, sampleRate: sampleRate);
    return _buildWavBytes(samples: samples, sampleRate: sampleRate);
  }

  /// ⏱️ Clock Ticking: Mechanical rhythmic clock tick pulse every 1.0 second.
  static Uint8List _generateClockTickWav({int seconds = 4, int sampleRate = 22050}) {
    final totalSamples = seconds * sampleRate;
    final samples = List<double>.filled(totalSamples, 0.0);

    for (var sec = 0; sec < seconds; sec++) {
      final tickStart = sec * sampleRate;
      final tickLen = (sampleRate * 0.035).toInt();
      for (var j = 0; j < tickLen && (tickStart + j) < totalSamples; j++) {
        final t = j / sampleRate;
        final env = exp(-t * 280.0);
        // High click frequency (2400 Hz) followed by body resonance (600 Hz)
        final click = (sin(2 * pi * 2400.0 * t) * 0.6 + sin(2 * pi * 620.0 * t) * 0.4) * env;
        samples[tickStart + j] += click * 0.45;
      }
    }

    return _buildWavBytes(samples: samples, sampleRate: sampleRate);
  }

  /// 🔔 Meditation Chime: Harmonic Tibetan singing bowl / completion bell.
  static Uint8List _generateMeditationChimeWav({int seconds = 3, int sampleRate = 22050}) {
    final totalSamples = seconds * sampleRate;
    final samples = List<double>.filled(totalSamples, 0.0);

    const f1 = 528.0; // Solfeggio frequency
    const f2 = 1056.0;
    const f3 = 1584.0;

    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final decay = exp(-t * 1.6);
      final chime = (sin(2 * pi * f1 * t) * 0.55 +
              sin(2 * pi * f2 * t) * 0.28 +
              sin(2 * pi * f3 * t) * 0.14) *
          decay;
      samples[i] = chime * 0.65;
    }

    return _buildWavBytes(samples: samples, sampleRate: sampleRate);
  }

  /// Crossfades start and end of samples to make audio perfectly loopable without clicks.
  static void _applySeamlessCrossfade(
    List<double> samples, {
    required int sampleRate,
    double fadeSeconds = 0.4,
  }) {
    final fadeSamples = (fadeSeconds * sampleRate).toInt().clamp(1, samples.length ~/ 3);
    for (var i = 0; i < fadeSamples; i++) {
      final progress = i / fadeSamples;
      final tailIndex = samples.length - fadeSamples + i;

      final startVal = samples[i];
      final tailVal = samples[tailIndex];

      samples[i] = (startVal * progress) + (tailVal * (1.0 - progress));
      samples[tailIndex] = samples[i];
    }
  }
}
