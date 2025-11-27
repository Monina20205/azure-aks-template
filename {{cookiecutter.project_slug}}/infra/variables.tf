variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  default     = "rg-my-own-lap"
}

variable "location" {
  description = "Región de Azure"
  default     = "eastus2"
}

# --- AQUÍ ESTÁ EL CAMBIO CLAVE ---
# Ya no pedimos el nombre completo, solo el prefijo (ej. "acr")
variable "acr_prefix" {
  description = "Prefijo para el Azure Container Registry"
  default     = "acr"
}
# ---------------------------------

variable "cluster_name" {
  description = "Nombre del cluster AKS"
  default     = "aks-my-own-lap"
}

variable "kubernetes_version" {
  description = "Version de Kubernetes"
  default     = "1.29.7"
}