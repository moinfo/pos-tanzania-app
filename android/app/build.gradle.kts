import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
            resValue("string", "app_name", "Moinfotech")
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

flutter {
    source = "../.."
}
