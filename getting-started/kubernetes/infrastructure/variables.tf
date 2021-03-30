variable "kubernetes_version" {
  default = "1.19.7"
}

variable "location" {
  type = string
  default = "northeurope"
}

variable "deployment_prefix" {
  type = string
}

variable "log_analytics_workspace_sku"{
  type = string
  default = "PerGB2018"
}

variable "default_node_pool" {
  type = object({
    agent_count = number
    size = string
  })
  default = {
    agent_count = 1 
    size = "Standard_D2_v3"
  }
}

variable additional_node_pool {
  default = {
      node_count = 1
      size = "Standard_D2_v3"
    }
}  