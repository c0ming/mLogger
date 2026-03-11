plugins {
    id("com.android.library") version "7.4.2"
    kotlin("android") version "1.8.10"
}

android {
    namespace = "com.codex.logger"
    compileSdk = 32

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        unitTests.all {
            it.testLogging {
                events("passed", "failed", "skipped")
                exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
                showExceptions = true
                showCauses = true
                showStackTraces = true
            }
            it.afterSuite(
                KotlinClosure2<org.gradle.api.tasks.testing.TestDescriptor, org.gradle.api.tasks.testing.TestResult, Unit>(
                    { descriptor, result ->
                        if (descriptor.parent == null) {
                            println(
                                "Android unit tests: ${result.resultType} " +
                                    "(passed=${result.successfulTestCount}, failed=${result.failedTestCount}, skipped=${result.skippedTestCount}, total=${result.testCount})"
                            )
                        }
                    }
                )
            )
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
