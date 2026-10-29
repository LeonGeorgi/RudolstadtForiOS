plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.kmp.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}

val kotlinFormatter by configurations.creating {
    isCanBeConsumed = false
    isTransitive = false
    attributes {
        attribute(Bundling.BUNDLING_ATTRIBUTE, objects.named(Bundling.SHADOWED))
        attribute(Usage.USAGE_ATTRIBUTE, objects.named(Usage.JAVA_RUNTIME))
    }
}

dependencies { kotlinFormatter(libs.ktfmt) }

val kotlinSources =
    fileTree("shared/src") { include("**/*.kt") } +
        fileTree("androidApp/src") { include("**/*.kt") } +
        files(
            "build.gradle.kts",
            "settings.gradle.kts",
            "shared/build.gradle.kts",
            "androidApp/build.gradle.kts",
        )

fun registerKotlinFormatter(name: String, checkOnly: Boolean) =
    tasks.register<JavaExec>(name) {
        group = "verification"
        description =
            if (checkOnly) "Check Kotlin formatting without writing files"
            else "Format Kotlin sources and Gradle scripts"
        classpath = kotlinFormatter
        mainClass.set("com.facebook.ktfmt.cli.Main")
        inputs.files(kotlinSources)
        args("--kotlinlang-style")
        if (checkOnly) args("--dry-run", "--set-exit-if-changed")
        args(kotlinSources.files.sorted().map { it.absolutePath })
    }

registerKotlinFormatter("formatKotlin", false)

registerKotlinFormatter("checkKotlinFormat", true)
