resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# --- Azure Container Registry (ACR) ---
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard" # Standard permite escaneos de seguridad básicos
  admin_enabled       = true       # Habilitado para facilitar logins iniciales
}

# --- Azure Kubernetes Service (AKS) ---
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "{{ cookiecutter.project_slug }}"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_DS2_v2" # Económico pero capaz
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  tags = {
    Environment = "Production"
    CreatedBy   = "Terraform"
  }
}

# --- Permisos: AKS necesita permiso para "jalar" (pull) imágenes de ACR ---
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# ... (Tu código anterior de AKS) ...

# --- Generación de nombre único seguro ---
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# --- Storage Account para la Aplicación (Logs/Archivos) ---
resource "azurerm_storage_account" "app_storage" {
  # Creamos un nombre único tipo: "storeinventoryx9z1"
  name                     = "st${replace(var.cluster_name, "-", "")}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Local Redundancy (Más barato para dev/test)

  tags = {
    environment = "Production"
    created_by  = "Terraform"
  }
}

# --- File Share (Opcional: Por si los contenedores necesitan compartir archivos) ---
resource "azurerm_storage_share" "app_share" {
  name                 = "app-data-share"
  storage_account_name = azurerm_storage_account.app_storage.name
  quota                = 50 # GB
}