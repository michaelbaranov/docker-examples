output "sql_fqdn" {
  value = azurerm_sql_server.sql.fully_qualified_domain_name
}

output "aks" {
  value = azurerm_kubernetes_cluster.aks.fqdn
}

output "publicdns_cd" {
  value = "cd.${azurerm_public_ip.nginx_ingress.fqdn}"
}