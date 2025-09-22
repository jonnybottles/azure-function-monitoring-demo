# Azure Function App with Monitoring & Load Testing - Terraform Deployment

## Overview

This Terraform Infrastructure as Code (IaC) project deploys an Azure Function App with monitoring, alerting, auto-scaling, and Azure Load Testing capabilities. The infrastructure demonstrates enterprise-grade monitoring patterns with configurable settings and professional load testing integration.

## Prerequisites

### Required Software

1. **Azure CLI**: Download from https://aka.ms/installazurecliwindows
   - Load Testing Extension: `az extension add --name load`
2. **Terraform**: Download from https://www.terraform.io/downloads
   - Extract terraform.exe to a folder (e.g., `C:\terraform`)
   - Add folder to system PATH
3. **Azure subscription** with appropriate permissions

## Architecture Components

### Core Infrastructure

- **Resource Group**: `{project-name}-rg-{random}` with random suffix for uniqueness
- **Function App**: `{project-name}-func-{random}` (Node.js 22 LTS)
- **App Service Plan**: `{project-name}-plan-{random}` (Configurable SKU with autoscaling)
- **Storage Account**: Auto-generated unique name with random suffix
- **Application Insights**: `{project-name}-ai-{random}` for monitoring
- **Log Analytics Workspace**: `{project-name}-law-{random}` for centralized logging
- **Azure Load Testing**: `{project-name}-loadtest-{random}` service

### Monitoring & Alerting

- **Azure Monitor Workbook**: Professional grouped dashboard with 6 sections including real-time instance tracking
- **4 Configurable Alert Rules**: All sending emails to specified address
  - Data ingress threshold (configurable bytes)
  - Response time threshold (configurable seconds)
  - HTTP 5xx errors threshold (configurable count)
  - Memory usage threshold (configurable percentage)
- **Action Group**: Email notifications for all alerts
- **Real-time Autoscaling Visualization**: Monitor instance count changes with KQL-based queries

### Function App Auto-Scaling

- **Automatic Scaling Rules**:
  - Scale OUT when data ingress exceeds threshold
  - Scale IN when data ingress falls below threshold
- **Configurable instance limits**: Min/max instance counts
- **Load Testing Validation**: Verify scaling behavior under controlled load

## Configuration

### Variable Configuration File

This project uses a `terraform.tfvars` file for customization. **Do not commit your `terraform.tfvars` file to version control.**

#### Getting Started with Variables

1. Copy the provided template file:
   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values

3. Do not commit your `terraform.tfvars` to the repository

Key settings include:

```hcl
# Core Settings
project_name         = "function-monitor"    # Base name for resources
location            = "Sweden Central"       # Azure region
alert_email         = "your@email.com"      # Alert recipient

# Infrastructure
app_service_plan_sku = "P1v2"               # Pricing tier (P1v2, P2v2, S1, etc.)

# Alert Thresholds
alert_thresholds = {
  data_in_bytes     = 1      # Trigger when data received exceeds (bytes)
  response_time_sec = 2      # Trigger when response time exceeds (seconds)
  memory_percent    = 80     # Trigger when memory usage exceeds (%)
  http_errors_count = 10     # Trigger when HTTP 5xx errors exceed (count)
}

# Auto-scaling
autoscale_min_instances = 1  # Minimum instances
autoscale_max_instances = 10 # Maximum instances
```

## Deployment

### Full Infrastructure Deployment

```powershell
# 1. Login to Azure
az login

# 2. Install Load Testing extension
az extension add --name load

# 3. Initialize Terraform
terraform init

# 4. Review the deployment plan
terraform plan

# 5. Deploy the infrastructure
terraform apply

# 6. Create load test (after infrastructure deployment)
./create-simple-load-test.ps1
```

### Deployment Outputs

After successful deployment, Terraform provides:
- Function App URL and trigger endpoint
- Load Test Data Plane URI and Portal URL
- Application Insights key (sensitive)
- Resource group and storage account names

## Load Testing

### Azure Load Testing Integration

The project includes comprehensive Azure Load Testing setup:

#### JMeter Script Features
- **Parameterized Tests**: Dynamic function URL and request configuration
- **Concurrent User Simulation**: Configurable virtual users and ramp-up
- **Response Validation**: Automated success/failure detection
- **Data Export**: Results available in multiple formats

#### Server-Side Metrics Collection
- **Application Insights Metrics**: Request rates, response times, success rates
- **App Service Plan Metrics**: CPU percentage, memory usage, HTTP queue length
- **Autoscaling Metrics**: Instance count changes and scaling triggers

#### Load Test Execution

```powershell
# Create and run a simple load test
./create-simple-load-test.ps1

# Configure advanced server-side metrics
./configure-load-test-metrics.ps1
```

#### Generated Test Files
- `load-test.jmx`: JMeter script with parameterized function URL
- `load-test-config.yaml`: Azure Load Testing configuration with server-side metrics

### Local Load Testing

For immediate testing without Azure Load Testing setup:

```powershell
# Run the generated trigger script
./trigger-autoscale.ps1
```

This generates traffic to test autoscaling and monitor through the workbook dashboard.

## File Structure

```
.
├── main.tf                           # Core infrastructure (Function App, monitoring)
├── load-testing.tf                   # Azure Load Testing infrastructure
├── workbook-grouped-layout.json      # Professional Azure Monitor Workbook template
├── trigger-autoscale-template.ps1    # PowerShell load testing template
├── load-test.jmx.tpl                 # JMeter script template
├── load-test-config.yaml.tpl         # Azure Load Testing configuration template
├── create-simple-load-test.ps1       # Script to create Azure Load Tests
├── configure-load-test-metrics.ps1   # Script to configure server-side metrics
├── terraform.tfvars.example          # Configuration template
├── .gitignore                        # Comprehensive ignore rules
├── README.md                         # This documentation
└── function-app/                     # Function App source code
    ├── host.json                     # Function runtime configuration
    ├── package.json                  # Node.js dependencies
    └── HttpTrigger1/                 # HTTP trigger function
        ├── function.json             # Function bindings
        └── index.js                  # Function implementation
```

### Generated Files (Not in Git)
```
├── trigger-autoscale.ps1             # Generated with actual function URL
├── load-test.jmx                     # Generated JMeter script
├── load-test-config.yaml             # Generated load test configuration
├── function-app.zip                  # Deployment package
└── tfplan                            # Terraform plan files
```

## Resource Naming Convention

Resources use randomized suffixes for global uniqueness.

Example with `project_name = "monitor"`:
- Resource Group: `monitor-rg-7mpz31`
- Function App: `monitor-func-7mpz31`
- Load Testing: `monitor-loadtest-7mpz31`
- Application Insights: `monitor-ai-7mpz31`

## Troubleshooting

### Monitoring Issues

#### "Application could not be found" Error in Workbook
**Solutions**:
1. Hard refresh: Press `Ctrl+F5`
2. Clear browser cache
3. Open in incognito mode
4. Wait 5-10 minutes for telemetry propagation

#### Instance Count Shows Only 1 Despite Multiple Instances
**Cause**: Different data sources (planned vs. active instances).

**Solution**:
1. Generate significant load using Azure Load Testing or trigger script
2. Wait 2-5 minutes for autoscaling and telemetry
3. Refresh workbook to see updated counts

### Deployment Issues

#### Resource name conflicts
**Solution**: The random suffix should prevent conflicts, but if issues persist:
- Deploy to different Azure region
- Modify `project_name` variable
- Run `terraform destroy` and `terraform apply` again

## Cleanup

To remove all deployed resources:

```powershell
terraform destroy -auto-approve
```

**Note**: This removes all resources including load tests, monitoring data, and storage.

## Additional Resources

- [Azure Load Testing Documentation](https://docs.microsoft.com/azure/load-testing/)
- [Azure Functions Best Practices](https://docs.microsoft.com/azure/azure-functions/functions-best-practices)
- [Application Insights Overview](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [JMeter Documentation](https://jmeter.apache.org/usermanual/index.html)

---

**Last Updated**: September 2025  
**Terraform Version**: >= 1.0  
**Azure Provider Version**: ~> 3.0