terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}

provider "archive" {}

provider "random" {}

provider "local" {}

# Variables
variable "project_name" {
  description = "Base name for all resources (max 16 characters)"
  type        = string
  default     = "function-monitor"
  
  validation {
    condition     = length(var.project_name) <= 16
    error_message = "Project name must be 16 characters or less."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Sweden Central"
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "jonbutler@microsoft.com"
}

variable "app_service_plan_sku" {
  description = "App Service Plan SKU (e.g., P1v2, P2v2, S1)"
  type        = string
  default     = "P1v2"
}

variable "alert_thresholds" {
  description = "Alert threshold values"
  type = object({
    data_in_bytes     = number
    response_time_sec = number
    memory_percent    = number
    http_errors_count = number
  })
  default = {
    data_in_bytes     = 1
    response_time_sec = 2
    memory_percent    = 80
    http_errors_count = 10
  }
}

variable "autoscale_min_instances" {
  description = "Minimum number of instances for autoscaling"
  type        = number
  default     = 1
}

variable "autoscale_max_instances" {
  description = "Maximum number of instances for autoscaling"
  type        = number
  default     = 10
}

# Random string for resource naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Random string for storage account
resource "random_string" "storage" {
  length  = 8
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg-${random_string.suffix.result}"
  location = var.location
}

# Storage Account for Function App
resource "azurerm_storage_account" "main" {
  name                     = "stfuncmonitor${random_string.storage.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # Try to enable shared key access explicitly
  shared_access_key_enabled = true
}

# App Service Plan (Premium v2 P1V2)
resource "azurerm_service_plan" "main" {
  name                = "${var.project_name}-plan-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Windows"
  sku_name            = var.app_service_plan_sku
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.project_name}-ai-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
}

# Get current subscription information
data "azurerm_client_config" "current" {}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-law-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Function App
resource "azurerm_windows_function_app" "main" {
  name                = "${var.project_name}-func-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name          = azurerm_storage_account.main.name
  storage_uses_managed_identity = true
  service_plan_id               = azurerm_service_plan.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    
    application_stack {
      node_version = "~20"
    }

    cors {
      allowed_origins     = ["https://portal.azure.com"]
      support_credentials = false
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"            = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"        = "~22"
    "FUNCTIONS_EXTENSION_VERSION"         = "~4"
    "WEBSITE_RUN_FROM_PACKAGE"            = "1"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    # Removed AzureWebJobsStorage to use Managed Identity
  }

  zip_deploy_file = data.archive_file.function_app.output_path

  depends_on = [
    azurerm_storage_account.main,
    azurerm_service_plan.main,
    azurerm_application_insights.main
  ]
}

# Grant Storage Blob Data Contributor to the Function App's Managed Identity
resource "azurerm_role_assignment" "function_storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_function_app.main.identity[0].principal_id
}

# Grant Storage Queue Data Contributor to the Function App's Managed Identity
resource "azurerm_role_assignment" "function_storage_queue_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.main.identity[0].principal_id
}

# Grant Storage Table Data Contributor to the Function App's Managed Identity
resource "azurerm_role_assignment" "function_storage_table_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_windows_function_app.main.identity[0].principal_id
}

# Diagnostic Settings for Function App
resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "function-app-diagnostics"
  target_resource_id         = azurerm_windows_function_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Diagnostic Settings for App Service Plan
resource "azurerm_monitor_diagnostic_setting" "app_service_plan" {
  name                       = "app-service-plan-diagnostics"
  target_resource_id         = azurerm_service_plan.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Diagnostic Settings for Application Insights
resource "azurerm_monitor_diagnostic_setting" "application_insights" {
  name                       = "application-insights-diagnostics"
  target_resource_id         = azurerm_application_insights.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AppAvailabilityResults"
  }

  enabled_log {
    category = "AppBrowserTimings"
  }

  enabled_log {
    category = "AppEvents"
  }

  enabled_log {
    category = "AppMetrics"
  }

  enabled_log {
    category = "AppDependencies"
  }

  enabled_log {
    category = "AppExceptions"
  }

  enabled_log {
    category = "AppPageViews"
  }

  enabled_log {
    category = "AppPerformanceCounters"
  }

  enabled_log {
    category = "AppRequests"
  }

  enabled_log {
    category = "AppSystemEvents"
  }

  enabled_log {
    category = "AppTraces"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Note: Subscription-level Activity Log diagnostic setting removed due to provider inconsistency issues
# You can create this manually in the Azure portal if needed:
# Monitor > Activity Log > Export Activity Logs > Add diagnostic setting

# Archive the function app code
data "archive_file" "function_app" {
  type        = "zip"
  source_dir  = "${path.module}/function-app"
  output_path = "${path.module}/function-app.zip"
}

# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "${var.project_name}-alerts-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "funcalerts"

  email_receiver {
    name          = "sendtoadmin"
    email_address = var.alert_email
  }
}

# Alert Rule 1: Data In Exceeds threshold
resource "azurerm_monitor_metric_alert" "data_in" {
  name                = "alert-data-in-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_windows_function_app.main.id]
  description         = "Alert when data in exceeds ${var.alert_thresholds.data_in_bytes} bytes"
  severity            = 3

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "BytesReceived"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.alert_thresholds.data_in_bytes
  }

  window_size        = "PT5M"
  frequency          = "PT1M"
  auto_mitigate      = true

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert Rule 2: High Response Time
resource "azurerm_monitor_metric_alert" "response_time" {
  name                = "alert-response-time-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_windows_function_app.main.id]
  description         = "Alert when average response time exceeds ${var.alert_thresholds.response_time_sec} seconds"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HttpResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alert_thresholds.response_time_sec
  }

  window_size        = "PT5M"
  frequency          = "PT1M"
  auto_mitigate      = true

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert Rule 3: HTTP Server Errors
resource "azurerm_monitor_metric_alert" "http_errors" {
  name                = "alert-http-errors-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_windows_function_app.main.id]
  description         = "Alert when HTTP 5xx server errors exceed ${var.alert_thresholds.http_errors_count} requests"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.alert_thresholds.http_errors_count
  }

  window_size        = "PT15M"
  frequency          = "PT5M"
  auto_mitigate      = true

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert Rule 4: Memory Pressure
resource "azurerm_monitor_metric_alert" "memory_usage" {
  name                = "alert-memory-usage-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_service_plan.main.id]
  description         = "Alert when memory usage exceeds ${var.alert_thresholds.memory_percent}%"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alert_thresholds.memory_percent
  }

  window_size        = "PT5M"
  frequency          = "PT1M"
  auto_mitigate      = true

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Autoscale Settings (Manual Scale Rules - NOT Auto)
resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-${var.project_name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.main.id

  profile {
    name = "dataInScaling"

    capacity {
      default = var.autoscale_min_instances
      minimum = var.autoscale_min_instances
      maximum = var.autoscale_max_instances
    }

    # Scale Out Rule - Data In > threshold
    rule {
      metric_trigger {
        metric_name        = "BytesReceived"
        metric_resource_id = azurerm_windows_function_app.main.id
        metric_namespace   = "Microsoft.Web/sites"
        time_grain         = "PT1M"
        statistic          = "Sum"
        time_window        = "PT5M"
        time_aggregation   = "Total"
        operator           = "GreaterThan"
        threshold          = var.alert_thresholds.data_in_bytes
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # Scale In Rule - Data In < threshold
    rule {
      metric_trigger {
        metric_name        = "BytesReceived"
        metric_resource_id = azurerm_windows_function_app.main.id
        metric_namespace   = "Microsoft.Web/sites"
        time_grain         = "PT1M"
        statistic          = "Sum"
        time_window        = "PT5M"
        time_aggregation   = "Total"
        operator           = "LessThan"
        threshold          = var.alert_thresholds.data_in_bytes
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      custom_emails                          = [var.alert_email]
    }
  }
}

# Random UUID for workbook
resource "random_uuid" "workbook" {}

# Azure Monitor Workbook
resource "azurerm_application_insights_workbook" "main" {
  name                = random_uuid.workbook.result
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Function App Monitoring Dashboard"
  source_id           = lower(azurerm_application_insights.main.id)
  
  data_json = templatefile("${path.module}/workbook-grouped-layout.json", {
    app_service_plan_id = azurerm_service_plan.main.id
    app_insights_id     = azurerm_application_insights.main.id
  })
}



# Generate PowerShell script with dynamic URL
resource "local_file" "trigger_autoscale_script" {
  content = templatefile("${path.module}/trigger-autoscale-template.ps1", {
    function_app_trigger_url = "https://${azurerm_windows_function_app.main.default_hostname}/api/HttpTrigger1"
  })
  filename = "${path.module}/trigger-autoscale.ps1"
}

# ================================================================
# Load Testing Infrastructure
# Note: Azure Load Testing resources and configuration are defined in load-testing.tf
# After running 'terraform apply', run './create-load-test.ps1' to create the actual test
# ================================================================

# Outputs
output "function_app_url" {
  value       = "https://${azurerm_windows_function_app.main.default_hostname}"
  description = "The URL of the Function App"
}

output "function_app_trigger_url" {
  value       = "https://${azurerm_windows_function_app.main.default_hostname}/api/HttpTrigger1"
  description = "The URL of the HTTP trigger function"
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
  description = "The name of the storage account"
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
  description = "The name of the resource group"
}

output "application_insights_key" {
  value = azurerm_application_insights.main.instrumentation_key
  sensitive = true
  description = "The instrumentation key for Application Insights"
}