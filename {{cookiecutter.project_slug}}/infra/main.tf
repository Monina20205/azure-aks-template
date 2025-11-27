# Crear el Grupo de Recursos
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# --- GENERADOR DE NOMBRES ÚNICOS PARA ACR ---
resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false # Azure exige minúsculas para ACR
}

# Crear el Container Registry (Nombre dinámico)
resource "azurerm_container_registry" "acr" {
  # Concatenamos el prefijo (variable) + el sufijo aleatorio
  name                = "${var.acr_prefix}${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = true
}
# -------------------------------------------

# Crear el Cluster de Kubernetes (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-dns"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_DS2_v2"
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
}

# Permisos: Darle poder al AKS para leer del ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# --- STORAGE ADICIONAL (Para la App) ---
resource "random_string" "sa_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_storage_account" "app_storage" {
  name                     = "st${replace(var.cluster_name, "-", "")}${random_string.sa_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}