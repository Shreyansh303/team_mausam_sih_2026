plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.teammausam.mausam_app"
    // permission_handler_android 14.1.0 requires compileSdk 37; flutter.compileSdkVersion is
    // 36 on Flutter 3.47, so assembleDebug fails the AAR-metadata check without this pin.
    // Verified on macOS in H0 (docs/PROGRESS.md > Notes for next phase > H0, gotcha 3).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // docs/06_MOBILE_SPEC.md §Android config. Team Mausam prototype - NOT an IMD app id.
        applicationId = "com.teammausam.mausam_app"
        // docs/06_MOBILE_SPEC.md originally asked for minSdk 23 (Android 6.0). Flutter 3.47
        // ships MinSdkVersionMigration, which rewrites ANY hardcoded minSdk of 16..23 back to
        // `flutter.minSdkVersion` on every `flutter build apk` - a hardcoded 23 does not
        // survive a single build. flutter.minSdkVersion == 24 (Android 7.0) on this SDK, which
        // is also the floor Flutter warns below. See docs/PROGRESS.md > Deviations.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
