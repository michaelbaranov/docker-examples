terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.56"
    }
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resourceGroupName
  location = var.location

  lifecycle {
      ignore_changes = [
        tags
      ]
    }
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "random_password" "windows_admin_password" {
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

resource "azurerm_log_analytics_workspace" "la" {
    name                = "${var.deployment_prefix}-la-ws-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    sku                 = var.log_analytics_workspace_sku

    lifecycle {
      ignore_changes = [
        tags
      ]
    }
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

    lifecycle {
      ignore_changes = [
        tags
      ]
    }
}

resource "azurerm_kubernetes_cluster" "aks" {
    name                = var.aks_name
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    dns_prefix          = var.aks_name

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

    lifecycle {
      ignore_changes = [
        tags
      ]
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
  name                     = "${var.acrname}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Standard"
  admin_enabled            = false

  lifecycle {
      ignore_changes = [
        tags
      ]
    }
}

resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

resource "azurerm_public_ip" "nginx_ingress" {
  name                         = "nginx-ingress-pip"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  allocation_method            = "Static"
  domain_name_label            = var.publicDNSPrefix
  sku                          = "Standard"

  lifecycle {
      ignore_changes = [
        tags
      ]
    }
}

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace = "ingress-basic"
  create_namespace = true
  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.nginx_ingress.ip_address
  }

  set {
    name  = "controller.nodeSelector\\.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "defaultBackend.nodeSelector\\.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "controller.admissionWebhooks.patch.nodeSelector\\.kubernetes\\.io/os"
    value = "linux"
  }

  set{
    name = "controller.replicaCount"
    value = "1"
  }

  set {
    name = "controller.config.proxy-body-size"
    value = "10m"
    type = "string"
  }
}

resource "azurerm_sql_server" "sql" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sitecore"
  administrator_login_password = var.sql_admin_password

  lifecycle {
      ignore_changes = [
        tags
      ]
    }
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

  lifecycle {
      ignore_changes = [
        tags
      ]
    }
}

resource "azurerm_sql_firewall_rule" "firewall_azure_resources" {
  name                = "allow_azure"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_sql_server.sql.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}