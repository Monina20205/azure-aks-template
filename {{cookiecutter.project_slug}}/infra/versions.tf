terraform {
  required_version = ">= 1.0"

  # --- CONFIGURACIÓN PARA CI/CD ---
  # Lo dejamos vacío intencionalmente. Python inyectará los datos al iniciar.
  backend "azurerm" {}
  # -------------------------------

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = { # Necesario para el random_string que agregamos arriba
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}