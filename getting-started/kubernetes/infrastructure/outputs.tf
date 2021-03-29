output "sql_fqdn" {
  value = azurerm_sql_server.sql.fully_qualified_domain_name
}

output "sql_admin_login" {
  value = random_password.sql_admin_username.result
}

output "sql_admin_password" {
  value = random_password.sql_admin_username.result
}