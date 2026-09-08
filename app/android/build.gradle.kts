import org.gradle.api.tasks.compile.JavaCompile

allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 部分 Flutter 插件没有声明 Java 编译版本，默认会回退到 Java 8。
// 统一所有 Android 子项目的 Java 编译目标，避免 JDK 对 source/target 8 的弃用警告。
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

subprojects {
    // Flutter migrator 会强制 android.builtInKotlin=false，
    // 而 AGP9 感知的插件（file_picker 11.x）此时不会自行应用 Kotlin 插件，
    // 这里给它补上，否则其 Kotlin 源码不会被编译。
    if (name == "file_picker") {
        apply(plugin = "org.jetbrains.kotlin.android")
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>("kotlin") {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

// media_kit_libs_android_video 1.3.8 performs its download/copy work while
// configuring this task, but declares it as Exec without a command line.
// The actual task execution therefore fails with "command 'null'" after the
// artifacts have already been verified and copied. Skip only that empty exec.
gradle.projectsEvaluated {
    findProject(":media_kit_libs_android_video")
        ?.tasks
        ?.matching { it.name == "downloadDependencies" }
        ?.configureEach {
            onlyIf { false }
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
