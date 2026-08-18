import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase. The config lives per flavor in src/<flavor>/google-services.json
    // -- only mopos has one, because this Firebase project registers only
    // co.tz.mopos.pos and the plugin fails the build when the flavor's
    // applicationId is missing from the file it finds.
    id("com.google.gms.google-services")
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
        // flutter_local_notifications uses java.time, which only exists from
        // API 26. Desugaring back-fills it so the app still runs on the older
        // Android versions this minSdk supports.
        isCoreLibraryDesugaringEnabled = true
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
        targetSdk = 36  // Android 16 (Play target API requirement)
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
        create("kariakooShops") {
            dimension = "client"
            applicationId = "co.tz.kariakooshops.pos"
            resValue("string", "app_name", "Kariakoo Shops")
        }
        create("mopos") {
            dimension = "client"
            applicationId = "co.tz.mopos.pos"
            resValue("string", "app_name", "Mopos")
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
