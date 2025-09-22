Write-Host "Configuring Server-Side Metrics for Load Test" -ForegroundColor Green

# Get dynamic values from Terraform
Write-Host "Retrieving resource information from Terraform..." -ForegroundColor Cyan
$terraformOutput = terraform output -json | ConvertFrom-Json

$ResourceGroupName = $terraformOutput.resource_group_name.value
$LoadTestResourceName = $terraformOutput.load_test_resource_id.value.Split('/')[-1]
$FunctionAppName = $terraformOutput.function_app_name.value
$AppServicePlanName = $terraformOutput.app_service_plan_name.value
$AppInsightsName = $terraformOutput.app_insights_name.value

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Load Test Resource: $LoadTestResourceName" -ForegroundColor White
Write-Host "  Function App: $FunctionAppName" -ForegroundColor White
Write-Host "  App Service Plan: $AppServicePlanName" -ForegroundColor White
Write-Host "  Application Insights: $AppInsightsName" -ForegroundColor White

# Check Azure CLI authentication
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in"
    }
    Write-Host "Authenticated as: $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Host "Please run 'az login' first" -ForegroundColor Red
    exit 1
}

Write-Host "Getting Application Insights resource ID..." -ForegroundColor Cyan

# Get Application Insights resource ID
$appInsightsId = az resource show --resource-group $ResourceGroupName --name $AppInsightsName --resource-type "Microsoft.Insights/components" --query "id" -o tsv

if (-not $appInsightsId) {
    Write-Error "Could not find Application Insights resource: $AppInsightsName"
    exit 1
}

Write-Host "Application Insights ID: $appInsightsId" -ForegroundColor Green

Write-Host "Getting App Service Plan resource ID..." -ForegroundColor Cyan

# Get App Service Plan resource ID  
$appServicePlanId = az resource show --resource-group $ResourceGroupName --name $AppServicePlanName --resource-type "Microsoft.Web/serverfarms" --query "id" -o tsv

if (-not $appServicePlanId) {
    Write-Error "Could not find App Service Plan resource: $AppServicePlanName"
    exit 1
}

Write-Host "App Service Plan ID: $appServicePlanId" -ForegroundColor Green

Write-Host "Configuring server-side metrics for load test..." -ForegroundColor Cyan

# Create App Insights resource configuration JSON
$appInsightsConfig = @{
    "resourceId" = $appInsightsId
    "resourceName" = $AppInsightsName
    "resourceType" = "Microsoft.Insights/components"
    "displayName" = "Function App Monitoring"
    "kind" = "web"
} | ConvertTo-Json -Depth 10

# Save configuration to temporary file
$configFile = "app-insights-config.json"
$appInsightsConfig | Out-File -FilePath $configFile -Encoding UTF8

Write-Host "Adding Application Insights resource to load test..." -ForegroundColor Cyan

# Add App Insights as server-side metric source
$addAppInsightsCommand = "az load test app-component add --test-id `"$TestName`" --resource-group `"$ResourceGroupName`" --load-test-resource `"$LoadTestResourceName`" --app-component-id `"$appInsightsId`" --app-component-name `"$AppInsightsName`" --app-component-type `"Microsoft.Insights/components`" --app-component-kind web"

Write-Host "Command: $addAppInsightsCommand" -ForegroundColor Gray
Invoke-Expression $addAppInsightsCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "Application Insights added successfully!" -ForegroundColor Green
    
    Write-Host "The following server-side metrics will now be available in your load test results:" -ForegroundColor Cyan
    Write-Host "  • Application Insights Metrics:" -ForegroundColor White
    Write-Host "    - Request Rate" -ForegroundColor Gray
    Write-Host "    - Response Time" -ForegroundColor Gray
    Write-Host "    - Failed Request Rate" -ForegroundColor Gray
    Write-Host "    - Exceptions" -ForegroundColor Gray
    Write-Host "    - Dependency Calls" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  • App Service Plan Metrics (via App Insights):" -ForegroundColor White
    Write-Host "    - CPU Percentage" -ForegroundColor Gray
    Write-Host "    - Memory Percentage" -ForegroundColor Gray
    Write-Host "    - Instance Count" -ForegroundColor Gray
    Write-Host ""
    Write-Host "These metrics will correlate with your JMeter load test results!" -ForegroundColor Green
    Write-Host "Portal: $($terraformOutput.load_test_portal_url.value)" -ForegroundColor Cyan
} else {
    Write-Error "Failed to add Application Insights to load test"
}

# Clean up temporary files
if (Test-Path $configFile) {
    Remove-Item $configFile
}