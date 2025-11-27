variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  default     = "rg-{{ cookiecutter.project_slug }}"
}

variable "location" {
  description = "Región de Azure"
  default     = "{{ cookiecutter.azure_region }}"
}
# ... (resource_group arriba) ...

# 1. Generamos un sufijo aleatorio de 6 caracteres (letras y números)
resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false # Azure exige minúsculas para ACR
}

# 2. Creamos el ACR concatenando el prefijo + sufijo
resource "azurerm_container_registry" "acr" {
  # Ejemplo resultado: "acr" + "x9z1k2" = "acrx9z1k2"
  name                = "${var.acr_prefix}${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = true
}

# ... (resto del código igual) ...

variable "cluster_name" {
  description = "Nombre del cluster AKS"
  default     = "aks-{{ cookiecutter.project_slug }}"
}

variable "kubernetes_version" {
  default = "1.34.0"
}