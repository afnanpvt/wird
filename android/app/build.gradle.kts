import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Wird Dev")
            // workmanager (used by the Friends nudge background check)
            // requires API 23+. Bumped only for dev, not prod - prod never
            // compiles the Friends feature in, so it keeps reaching
            // whatever older devices flutter.minSdkVersion already covers.
            minSdk = maxOf(flutter.minSdkVersion, 23)
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
