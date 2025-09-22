# Azure Load Testing Infrastructure
# Separate file to keep main.tf clean

# Random string for load testing resource naming
resource "random_string" "load_test_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Azure Load Testing Resource
resource "azurerm_load_test" "main" {
  name                = "${var.project_name}-loadtest-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  description         = "Load testing resource for Function App autoscaling demonstration"
  
  tags = {
    Environment = "Demo"
    Purpose     = "Function App Load Testing"
  }
}

# Outputs for Load Testing
output "load_test_resource_id" {
  value       = azurerm_load_test.main.id
  description = "The resource ID of the Azure Load Testing resource"
}

output "load_test_data_plane_uri" {
  value       = azurerm_load_test.main.data_plane_uri
  description = "The data plane URI for the Azure Load Testing resource"
}

output "load_test_portal_url" {
  value       = "https://portal.azure.com/#@/resource${azurerm_load_test.main.id}"
  description = "Direct link to the Load Testing resource in Azure Portal"
}