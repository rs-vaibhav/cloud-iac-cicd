variable "project" {
  description = "Short project name used in resource names"
  type        = string
  default     = "notes"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralindia"
}

variable "vnet_cidr" {
  description = "Address space of the virtual network"
  type        = string
}

variable "aks_node_count" {
  description = "Initial node count of the AKS system pool"
  type        = number
  default     = 1
}

variable "aks_max_nodes" {
  description = "Max nodes for the cluster autoscaler"
  type        = number
  default     = 3
}

variable "aks_vm_size" {
  description = "VM size of AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version (null = latest default)"
  type        = string
  default     = null
}

variable "postgres_sku" {
  description = "PostgreSQL flexible server SKU"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage size in MB"
  type        = number
  default     = 32768
}

variable "postgres_ha" {
  description = "Enable zone-redundant high availability for PostgreSQL"
  type        = bool
  default     = false
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the ingress on 80/443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Extra tags applied to every resource"
  type        = map(string)
  default     = {}
}
