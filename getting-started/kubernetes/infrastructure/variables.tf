variable "kubernetes_version" {
  default = "1.19.7"
}

variable "location" {
  type = string
}

variable "deployment_prefix" {
  type = string
}

variable "acrname" {
  type=string
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
    size = "Standard_D2_v4"
  }
}

variable additional_node_pool {
  default = {
      node_count = 1
      size = "Standard_D8_v4"
    }
}  

variable "sql_admin_password" {
  type = string  
}

variable "sql_server_name" {
  type = string
}

variable "aks_name" {
  type = string
}

variable "resourceGroupName" {
  type = string
}

variable "elasticPoolName" {
  type = string
}