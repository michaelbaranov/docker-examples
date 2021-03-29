variable "kubernetes_version" {
  default = "1.19.7"
}

variable "location" {
  default = "northeurope"
}

variable "deployment_prefix" {
}

variable "log_analytics_workspace"{
  type = object({
    sku = string
  })
  default = ({
    sku = "PerGB2018"
  })
}

variable "default_node_pool" {
  type = object({
    agent_count = number
    size = string
  })
  default = {
    agent_count = 1 
    size = "Standard_D2_v2"
  }
}

variable additional_node_pool {
  default = {
      node_count = 1
      size = "Standard_D4_v2"
    }
}  