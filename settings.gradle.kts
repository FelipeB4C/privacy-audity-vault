pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        // Inserido: Repositorios necessarios para baixar o plugin do Spring Boot 4.x
        maven { url = uri("https://repo.spring.io/milestone") }
        maven { url = uri("https://repo.spring.io/snapshot") }
    }
}

rootProject.name = "privacy-audit-vault"
