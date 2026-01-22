# Signal 6: Oversized Database Tiers for Actual Usage
resource "azurerm_resource_group" "oversized_db" {
  name     = "rg-oversized-db-test"
  location = "East US"
}

# SIGNAL: High-tier SQL Database for low-usage application
resource "azurerm_mssql_server" "oversized_sql_server" {
  name                         = "sqlserver-oversized-001"
  resource_group_name          = azurerm_resource_group.oversized_db.name
  location                     = azurerm_resource_group.oversized_db.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd123!"
}

resource "azurerm_mssql_database" "oversized_db" {
  name      = "db-oversized"
  server_id = azurerm_mssql_server.oversized_sql_server.id

  # SIGNAL: S4 tier (200 DTUs) for development/low-usage app
  sku_name = "S0"

  tags = {
    Environment = "development"
    Usage       = "low"
    # SIGNAL: High DTU tier for development database
    CostIssue   = "oversized-for-usage"
  }
}

# SIGNAL: PostgreSQL with high vCores for minimal workload
resource "azurerm_postgresql_server" "oversized_postgres" {
  name                = "psql-oversized-001"
  location            = azurerm_resource_group.oversized_db.location
  resource_group_name = azurerm_resource_group.oversized_db.name

  administrator_login          = "psqladmin"
  administrator_login_password = "P@ssw0rd123!"

  sku_name   = "GP_Gen5_1" # Adjusted to 1 vCore for test environment
  version    = "11"
  storage_mb = 102400

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled           = false

  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"

  tags = {
    Environment = "test"
    Workload    = "minimal"
    # SIGNAL: 8 vCores for test workload
    CostIssue   = "oversized-vcores"
  }
}

# SIGNAL: Cosmos DB with high RU/s for simple application
resource "azurerm_cosmosdb_account" "oversized_cosmos" {
  name                = "cosmos-oversized-001"
  location            = azurerm_resource_group.oversized_db.location
  resource_group_name = azurerm_resource_group.oversized_db.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.oversized_db.location
    failover_priority = 0
  }

  tags = {
    Usage = "development"
    # SIGNAL: Cosmos DB setup for high throughput but used for dev
  }
}

resource "azurerm_cosmosdb_sql_database" "oversized_cosmos_db" {
  name                = "cosmos-db-oversized"
  resource_group_name = azurerm_resource_group.oversized_db.name
  account_name        = azurerm_cosmosdb_account.oversized_cosmos.name

  # SIGNAL: High throughput for simple dev application
  throughput = 400 # RU/s - adjusted for development
}

# SIGNAL: Redis Cache with Premium tier for caching simple data
resource "azurerm_redis_cache" "oversized_redis" {
  name                = "redis-oversized-001"
  location            = azurerm_resource_group.oversized_db.location
  resource_group_name = azurerm_resource_group.oversized_db.name
  capacity            = 1
  family              = "C" # Updated to Standard family for basic caching
  sku_name            = "Basic"

  enable_non_ssl_port = false

  redis_configuration {
    maxclients = 1000
  }

  tags = {
    Purpose = "basic-caching"
    # SIGNAL: Premium Redis for basic session storage
    CostIssue = "premium-for-basic-cache"
  }
}

# SIGNAL: Multiple database instances for single application
resource "azurerm_mssql_database" "redundant_db_1" {
  name      = "db-app-dev"
  server_id = azurerm_mssql_server.oversized_sql_server.id
  sku_name  = "S2" # 50 DTUs

  tags = {
    Environment = "development"
    App         = "web-app"
  }
}

# resource "azurerm_mssql_database" "redundant_db_2" {
#   name      = "db-app-test"
#   server_id = azurerm_mssql_server.oversized_sql_server.id
#   sku_name  = "S2" # SIGNAL: Another 50 DTUs for same app

#   tags = {
#     Environment = "test"
#     App         = "web-app"
#     # SIGNAL: Could share database with different schema
#     CostIssue   = "duplicate-database-instances"
#   }
# }

# SIGNAL: Always-on database for batch processing
resource "azurerm_mssql_database" "batch_db" {
  name      = "db-batch-processing"
  server_id = azurerm_mssql_server.oversized_sql_server.id
  sku_name  = "GP_S_Gen5_2" # Updated to serverless-compatible tier

  tags = {
    Usage     = "batch-daily"
    Schedule  = "once-per-day"
    # SIGNAL: Always-on database for sporadic batch processing
    CostIssue = "should-use-serverless"
  }
}