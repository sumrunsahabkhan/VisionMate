allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Fix for namespace issues and SDK version mismatches
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // Libraries like androidx.browser:1.9.0 and core:1.17.0 REQUIRE SDK 36
            android.compileSdkVersion(36)
            
            // Explicitly set namespaces for plugins to avoid manifest conflicts with AGP 8.0+
            when (project.name) {
                "flutter_beep" -> android.namespace = "com.gonoter.flutter_beep"
                "vosk_flutter" -> android.namespace = "com.alphacephei.vosk_flutter"
                "tflite_flutter" -> android.namespace = "org.tensorflow.tflite_flutter"
            }

            // Fallback for other plugins to prevent namespace errors
            if (android.namespace == null) {
                try {
                    android.namespace = "com.visionmate.generated.${project.name.replace("_", ".")}"
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
