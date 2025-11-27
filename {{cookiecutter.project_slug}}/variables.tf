variable "location" {
  description = "Azure Region"
  default     = "{{ cookiecutter.azure_region }}"
}

variable "acr_name" {
  description = "Azure Container Registry Name"
  default     = "{{ cookiecutter.acr_name }}"
}