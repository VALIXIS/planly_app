import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const String _feedbackEmail = 'support@planly.app';

  final TextEditingController _controller = TextEditingController();
  bool _submitted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final feedback = _controller.text.trim();
    if (feedback.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final uri = Uri(
      scheme: 'mailto',
      path: _feedbackEmail,
      queryParameters: {
        'subject': 'Planly App Feedback',
        'body': feedback,
      },
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;

      if (opened) {
        setState(() {
          _submitted = true;
          _controller.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No email app found. Please email $_feedbackEmail directly.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _submitted
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thank you for your feedback!',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _submitted = false;
                        });
                      },
                      child: const Text('Send More Feedback'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your feedback helps us improve Planly.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Type your feedback here...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        _controller.text.trim().isEmpty || _isSubmitting
                            ? null
                            : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ],
              ),
      ),
    );
  }
}
