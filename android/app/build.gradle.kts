import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()
val releaseAdMobAppId = (keystoreProperties["adMobAppId"] as String?)?.trim()
val isReleaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true) ||
        taskName.contains("bundle", ignoreCase = true)
}

android {
    namespace = "com.js.planly"
    ndkVersion = "28.2.13676358"

    // ✅ Fix 1: Raised to 36 (required by path_provider_android)
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // ✅ Fix 2: Required by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.js.planly"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["adMobAppId"] =
            releaseAdMobAppId?.takeIf { it.isNotEmpty() }
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Keep release build stable for now; can re-enable after adding full keep rules.
            isMinifyEnabled = false
            isShrinkResources = false
            // Use the default ProGuard rules file
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (!hasReleaseKeystore && isReleaseBuildRequested) {
                throw GradleException(
                    "Missing android/key.properties. Add release keystore details before building a Play Store bundle."
                )
            }
            if (isReleaseBuildRequested && releaseAdMobAppId.isNullOrEmpty()) {
                throw GradleException(
                    "Missing adMobAppId in android/key.properties. Add your real AdMob app ID before building a release bundle."
                )
            }
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // ✅ Required for core library desugaring (flutter_local_notifications needs this)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
