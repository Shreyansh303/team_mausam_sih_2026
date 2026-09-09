import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (README §Run it yourself → (c) Install the APK directly). The keystore and its
// passwords never enter git: `android/key.properties` and `*.jks` / `*.keystore` are gitignored,
// so a fresh clone — and CI, which has no secrets — still builds, signed with the debug key.
//
// key.properties (four lines, `storeFile` absolute or relative to `android/app/`):
//   storeFile=/absolute/path/to/mausam-release.jks
//   storePassword=…
//   keyAlias=mausam
//   keyPassword=…
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) keystorePropertiesFile.inputStream().use { load(it) }
}

/** Fails loudly rather than silently signing with a half-configured key. */
fun keystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException(
            "android/key.properties exists but has no `$name`. It needs all four of " +
                "storeFile, storePassword, keyAlias, keyPassword.",
        )

if (!hasReleaseKeystore) {
    // `logger.quiet`, not `logger.warn`: `flutter build apk` runs Gradle with `-q`, which
    // swallows WARN. Verified both ways on this Mac.
    logger.quiet(
        "WARNING: android/key.properties not found - the release build will be signed with the " +
            "DEBUG key. Fine for a demo APK; not publishable. See README > Run it yourself.",
    )
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperty("storeFile"))
                storePassword = keystoreProperty("storePassword")
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The real key when android/key.properties is there, the debug key when it is not —
            // `flutter build apk --release` has to keep working on a machine with no secrets
            // (this is what .github/workflows/flutter.yml builds).
            signingConfig = signingConfigs.getByName(if (hasReleaseKeystore) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // The home-screen widget's hourly background refresh (docs/06 §Home-screen widget).
    // Pinned to the version home_widget already pulls in, so there is one WorkManager on the
    // classpath, not two.
    implementation("androidx.work:work-runtime-ktx:2.11.2")
}

flutter {
    source = "../.."
}
