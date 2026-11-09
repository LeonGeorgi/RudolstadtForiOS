import java.util.zip.ZipFile
import java.util.zip.ZipInputStream
import org.jetbrains.kotlin.gradle.targets.native.internal.KotlinNativeDownloadTask

plugins {
    alias(libs.plugins.android.kmp.library)
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(17)
    androidLibrary {
        namespace = "de.leongeorgi.rudolstadt.core"
        compileSdk = 36
        minSdk = 26
    }
    jvm() // Fast common-domain tests without an emulator.
    iosArm64()
    iosSimulatorArm64()
    macosArm64()
    macosX64()
    watchosArm64()
    watchosDeviceArm64()
    watchosSimulatorArm64()
    watchosX64()
    targets.withType<org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeTarget>().configureEach {
        binaries.framework {
            baseName = "RudolstadtCore"
            isStatic = true
            binaryOption("bundleId", "de.leongeorgi.rudolstadt.core")
        }
    }
    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.kotlinx.datetime)
            api(libs.kotlinx.coroutines.core)
            implementation(libs.ktor.client.core)
        }
        appleMain.dependencies { implementation(libs.ktor.client.darwin) }
        androidMain.dependencies { implementation(libs.ktor.client.android) }
        jvmMain.dependencies { implementation(libs.ktor.client.okhttp) }
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation(libs.kotlinx.coroutines.test)
            implementation(libs.ktor.client.mock)
        }
    }
}

// Kotlin 2.4.21 writes the compiler path to build/konan.txt without tracking it as
// an input. Refresh that file when switching between local and isolated caches.
tasks.withType<KotlinNativeDownloadTask>().configureEach {
    inputs.property("konanHomePath", konanHome.map { it.asFile.absolutePath })
}

// Android includes commonMain resources as Java resources in classes.jar.
// Verify the actual AAR, including compilation and byte-identical shared data.
androidComponents {
    onVariants { variant ->
        val aar = variant.artifacts.get(com.android.build.api.artifact.SingleArtifact.AAR)
        tasks.register("verifyAndroidResources") {
            group = "verification"
            description = "Build the Android library and verify every shared resource in its AAR"
            inputs.file(aar)
            inputs.files(fileTree("src/commonMain/resources"))
            doLast {
                val expected =
                    fileTree("src/commonMain/resources").files.associateBy {
                        it.relativeTo(file("src/commonMain/resources")).invariantSeparatorsPath
                    }
                val found = mutableSetOf<String>()
                var hasCoreClasses = false
                ZipFile(aar.get().asFile).use { archive ->
                    val classes =
                        requireNotNull(archive.getEntry("classes.jar")) {
                            "Missing Android classes.jar"
                        }
                    ZipInputStream(archive.getInputStream(classes)).use { jar ->
                        var entry = jar.nextEntry
                        while (entry != null) {
                            val name = entry.name
                            if (name == "de/leongeorgi/rudolstadt/interop/CoreBridge.class")
                                hasCoreClasses = true
                            expected[name]?.let { source ->
                                check(jar.readBytes().contentEquals(source.readBytes())) {
                                    "Android resource differs: $name"
                                }
                                found += name
                            }
                            entry = jar.nextEntry
                        }
                    }
                }
                check(hasCoreClasses) { "Android library contains no compiled shared core" }
                check(found == expected.keys) {
                    "Missing Android resources: ${expected.keys - found}"
                }
            }
        }
    }
}
