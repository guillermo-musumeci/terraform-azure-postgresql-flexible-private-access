############################################
## PostgresSQL Private Access - Resources ##
############################################

# Create Private DNS Zone Virtual Network Link for PostgreSQL
resource "azurerm_private_dns_zone_virtual_network_link" "private" {
  name                  = "${lower(replace(var.company," ","-"))}-${var.app_name}-${var.environment}-vnet-link"
  resource_group_name   = data.azurerm_private_dns_zone.postgres_dns_zone.resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.postgres_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.this.id

  depends_on = [ azurerm_subnet.postgres, azurerm_virtual_network.this ]
}

# Create Private PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "private" {
  name                = "${lower(replace(var.company," ","-"))}-${var.app_name}-${var.environment}-postgresql-private"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  version  = var.postgres_server_version
  sku_name = var.postgres_server_sku
  
  public_network_access_enabled = false

  private_dns_zone_id = data.azurerm_private_dns_zone.postgres_dns_zone.id
  delegated_subnet_id = azurerm_subnet.postgres.id

  administrator_login    = var.postgres_user
  administrator_password = var.postgres_password
  
  storage_mb   = var.postgres_server_storage_mb
  storage_tier = var.postgres_server_storage_tier

  tags = var.tags

  depends_on = [ azurerm_subnet.postgres, azurerm_private_dns_zone_virtual_network_link.private ]
}

# Create PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "private" {
  name                = "${var.app_name}-${var.environment}-db-private"
  server_id           = azurerm_postgresql_flexible_server.private.id
  charset             = var.postgres_database_charset
  collation           = var.postgres_database_collation

  # To  prevent the possibility of accidental data loss change to true in production
  lifecycle {
    prevent_destroy = false
  }

  depends_on = [ azurerm_postgresql_flexible_server.private ]
} 

# Enable PostgreSQL Extensions
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.private.id
  value     = "VECTOR"
}

###########################################
## PostgresSQL Private Database - Output ##
###########################################

output "private_postgresql_server_name" {
  value       = azurerm_postgresql_flexible_server.private.name
  description = "The name of the PostgreSQL Server"
}

output "private_postgresql_database_name" {
  value       = azurerm_postgresql_flexible_server_database.private.name
  description = "The name of the PostgreSQL Database"
}

