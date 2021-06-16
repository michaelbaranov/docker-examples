output "sql_fqdn" {
  value = azurerm_sql_server.sql.fully_qualified_domain_name
}

output "aks" {
  value = azurerm_kubernetes_cluster.aks.fqdn
}

output "publicdns_cd" {
  value = azurerm_dns_a_record.cd_dns_record.fqdn
}

output "publicdns_cm" {
  value = azurerm_dns_a_record.cm_dns_record.fqdn
}

output "publicdns_horizon" {
  value = azurerm_dns_a_record.hrz_dns_record.fqdn
}