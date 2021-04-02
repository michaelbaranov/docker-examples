terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
  backend "local" {}
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_prefix}-aks"
  location = var.location
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "random_id" "acr_name_suffix" {
    byte_length = 8
}

resource "random_password" "windows_admin_password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

resource "random_password" "sql_admin_password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

resource "random_password" "windows_admin_username" {
  length    = 16
  min_upper = 1
  min_lower = 1
  special   = false
}

resource "random_password" "sql_admin_username" {
  length    = 16
  min_upper = 1
  min_lower = 1
  special   = false
}

resource "azurerm_log_analytics_workspace" "la" {
    name                = "${var.deployment_prefix}-la-ws-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_log_analytics_solution" "la" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.la.location
    resource_group_name   = azurerm_resource_group.rg.name
    workspace_resource_id = azurerm_log_analytics_workspace.la.id
    workspace_name        = azurerm_log_analytics_workspace.la.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_kubernetes_cluster" "aks" {
    name                = "${var.deployment_prefix}-aks"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    dns_prefix          = "${var.deployment_prefix}-aks"

    default_node_pool {
        name            = "default"
        node_count      = var.default_node_pool.agent_count
        vm_size         = var.default_node_pool.size
        availability_zones = ["1"]
    }

    identity {
      type = "SystemAssigned"
    }

    windows_profile {
      admin_username = random_password.windows_admin_username.result
      admin_password = random_password.windows_admin_password.result
    }

    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = azurerm_log_analytics_workspace.la.id
        }
    }

    network_profile {
      network_plugin = "azure"
    }
}

resource "azurerm_kubernetes_cluster_node_pool" "node_pools" {
    kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
    name                  = "win"
    vm_size               = var.additional_node_pool.size
    node_count            = var.additional_node_pool.node_count
    os_type               = "Windows"
    priority              = "Regular"
    availability_zones    = ["1"]
}

resource "azurerm_container_registry" "acr" {
  name                     = "${var.deployment_prefix}acr${random_id.acr_name_suffix.dec}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Standard"
  admin_enabled            = false
}

resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

resource "azurerm_sql_server" "sql" {
  name                         = "${var.deployment_prefix}-sql-server"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = random_password.sql_admin_username.result
  administrator_login_password = random_password.sql_admin_password.result
}

resource "azurerm_mssql_elasticpool" "elasticpool" {
  name                = "${var.deployment_prefix}-epool"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_sql_server.sql.name
  license_type        = "LicenseIncluded"
  max_size_gb         = 32

  sku {
    name     = "GP_Gen5"
    tier     = "GeneralPurpose"
    family   = "Gen5"
    capacity = 2
  }

  per_database_settings {
    min_capacity = 0
    max_capacity = 1
  }
}