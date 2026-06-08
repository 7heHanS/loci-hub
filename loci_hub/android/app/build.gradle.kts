import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        load(FileInputStream(localPropertiesFile))
    }
}
val mapsApiKey = localProperties.getProperty("MAPS_API_KEY") ?: "PLACEHOLDER_API_KEY"

android {
    namespace = "com.locihub.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.locihub.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 34
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
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

tasks.register("copyLocalEnvToAssets") {
    doLast {
        val userHome = System.getProperty("user.home")
        val envFile = file("$userHome/.env")
        if (envFile.exists()) {
            val originalAssetsDir = file("${project.projectDir}/../../assets")
            if (!originalAssetsDir.exists()) {
                originalAssetsDir.mkdirs()
            }
            envFile.copyTo(file("$originalAssetsDir/config.env"), overwrite = true)
            println("✅ [copyLocalEnvToAssets] Copied local ~/.env to assets/config.env")
            
            val flutterAssetsDir = file("${project.projectDir}/../../build/flutter_assets/assets")
            if (flutterAssetsDir.exists()) {
                envFile.copyTo(file("$flutterAssetsDir/config.env"), overwrite = true)
                println("✅ [copyLocalEnvToAssets] Copied to build/flutter_assets/assets/config.env")
            }
        }
    }
}

tasks.named("preBuild") {
    dependsOn("copyLocalEnvToAssets")
}
