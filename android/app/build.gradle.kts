plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "co.tz.moinfotech.pos"
    compileSdk = 36  // Required by plugins
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Base Application ID - will be overridden by flavors
        applicationId = "co.tz.moinfotech.pos"
        minSdk = flutter.minSdkVersion  // Android 5.0 - supports 99%+ of devices
        targetSdk = 35  // Android 15
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Product Flavors - Each client gets a unique app
    flavorDimensions += "client"

    productFlavors {
        create("sada") {
            dimension = "client"
            applicationId = "co.tz.sada.pos"
            resValue("string", "app_name", "SADA POS")
        }
        create("comeAndSave") {
            dimension = "client"
            applicationId = "co.tz.comeandsave.pos"
            resValue("string", "app_name", "Come & Save POS")
        }
        create("leruma") {
            dimension = "client"
            applicationId = "co.tz.leruma.pos"
            resValue("string", "app_name", "Leruma POS")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
