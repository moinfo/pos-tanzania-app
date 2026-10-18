import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Version comes from the `apply false` declaration in settings.gradle.kts.
    id("com.google.gms.google-services")
}

// ---------------------------------------------------------------------------
// The `leruma` flavor has its google-services.json at src/leruma/. WARN keeps
// a build without one (e.g. a debug build on a fresh checkout) from failing;
// the Dart side treats "Firebase unavailable" as a normal state and falls back
// to polling.
// ---------------------------------------------------------------------------
configure<com.google.gms.googleservices.GoogleServicesPlugin.GoogleServicesPluginConfig> {
    missingGoogleServicesStrategy =
        com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.WARN
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "co.tz.moinfotech.pos"
    compileSdk = 36  // Required by plugins
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications needs the desugared java.time classes.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Base Application ID - will be overridden by flavors
        applicationId = "co.tz.moinfotech.pos"
        minSdk = flutter.minSdkVersion  // Android 5.0 - supports 99%+ of devices
        targetSdk = 36  // Android 16
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Product Flavors - Each client gets a unique app
    flavorDimensions += "client"

    productFlavors {
        create("leruma") {
            dimension = "client"
            applicationId = "co.tz.leruma.pos"
            resValue("string", "app_name", "Leruma Distribution Center")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
