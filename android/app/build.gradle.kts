import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The plugin needs a src/{flavor}/google-services.json for every flavor
// it's applied to, or it hard-fails that flavor's build. src/prod/ and
// src/dev/ each hold an identical copy containing both flavors' client
// entries (com.afnan.wird and com.afnan.wird.dev, both registered under
// the wird-dev Firebase project) - the plugin picks whichever entry
// matches the variant actually being built. Prod's entry is never
// exercised at runtime (FeatureFlags.friendsEnabled compiles to false
// there - see lib/config/feature_flags.dart, so Firebase.initializeApp()
// never runs in prod); it exists purely to satisfy this plugin's check.

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasLocalKeystore = keystorePropertiesFile.exists()
if (hasLocalKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// CI provides the same values via env vars instead of a checked-in key.properties.
val hasCiKeystore = System.getenv("WIRD_KEYSTORE_PATH") != null

android {
    namespace = "com.afnan.wird"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Required for the dev flavor's resValue("string", "app_name", ...)
    // below - AGP's resValues generation is opt-in.
    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (used by the Friends nudge check)
        // requires core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.afnan.wird"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasLocalKeystore || hasCiKeystore) {
            create("release") {
                storeFile = if (hasLocalKeystore) rootProject.file(keystoreProperties["storeFile"] as String)
                    else file(System.getenv("WIRD_KEYSTORE_PATH")!!)
                storePassword = if (hasLocalKeystore) keystoreProperties["storePassword"] as String
                    else System.getenv("WIRD_KEYSTORE_PASSWORD")
                keyAlias = if (hasLocalKeystore) keystoreProperties["keyAlias"] as String
                    else System.getenv("WIRD_KEY_ALIAS")
                keyPassword = if (hasLocalKeystore) keystoreProperties["keyPassword"] as String
                    else System.getenv("WIRD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasLocalKeystore || hasCiKeystore) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
        }
    }

    // "prod" is the public app (Play Store, default flavor). "dev" gets its own
    // application ID and label so it installs alongside prod on the same
    // device instead of replacing it - used for testing features (like
    // Friends) that shouldn't reach the public build yet.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            // workmanager (used by the Friends nudge background check)
            // requires API 23+. Friends now ships in prod too (opt-in,
            // gated behind the FRIENDS_ENABLED dart-define set in the
            // release workflow), so prod needs the same floor as dev.
            minSdk = maxOf(flutter.minSdkVersion, 23)
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Wird Dev")
            minSdk = maxOf(flutter.minSdkVersion, 23)
        }
        // Identical to "dev" in every way except its own application ID and
        // label - exists purely so two independent Friends identities can be
        // installed side by side on the same test device (e.g. your own
        // phone), so you can add "Wird Dev" and "Wird Dev 2" as friends to
        // each other without needing a second physical device. Not for
        // anyone but the developer's own testing.
        create("dev2") {
            dimension = "env"
            applicationIdSuffix = ".dev2"
            resValue("string", "app_name", "Wird Dev 2")
            minSdk = maxOf(flutter.minSdkVersion, 23)
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
