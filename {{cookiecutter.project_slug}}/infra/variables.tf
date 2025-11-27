variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  default     = "rg-{{ cookiecutter.project_slug }}"
}

variable "location" {
  description = "Región de Azure"
  default     = "{{ cookiecutter.azure_region }}"
}

variable "acr_name" {
  description = "Nombre del Azure Container Registry (debe ser único globalmente)"
  default     = "{{ cookiecutter.acr_name }}"
}

variable "cluster_name" {
  description = "Nombre del cluster AKS"
  default     = "aks-{{ cookiecutter.project_slug }}"
}

variable "kubernetes_version" {
  default = "{{ cookiecutter.kubernetes_version }}"
}