Write-Host "Azure Load Test Creation Script with JMeter Upload" -ForegroundColor Green

# Get dynamic values from Terraform
Write-Host "Retrieving resource information from Terraform..." -ForegroundColor Cyan
$terraformOutput = terraform output -json | ConvertFrom-Json

$ResourceGroupName = $terraformOutput.resource_group_name.value
$LoadTestResourceName = $terraformOutput.load_test_resource_id.value.Split('/')[-1]
$FunctionHostname = $terraformOutput.function_app_url.value.Replace("https://", "")
$FunctionPath = "/api/HttpTrigger1"
$TestName = "scale-out-bytes-$(Get-Random -Minimum 100000 -Maximum 999999)"
$VirtualUsers = 50
$RampUpSeconds = 30
$TestDurationSeconds = 120

Write-Host "Test Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Load Test Resource: $LoadTestResourceName" -ForegroundColor White
Write-Host "  Test Name: $TestName" -ForegroundColor White
Write-Host "  Target: https://$FunctionHostname$FunctionPath" -ForegroundColor White
Write-Host "  Virtual Users: $VirtualUsers" -ForegroundColor White
Write-Host "  Ramp Up: $RampUpSeconds seconds" -ForegroundColor White
Write-Host "  Duration: $TestDurationSeconds seconds" -ForegroundColor White

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

Write-Host "Installing Azure Load Testing extension..." -ForegroundColor Cyan
az extension add --name load

Write-Host "Creating parameterized JMeter test file..." -ForegroundColor Green

# Read the template and create the parameterized JMeter file
$templateContent = Get-Content "load-test.jmx.tpl" -Raw
$jmeterContent = $templateContent -replace '\$\{function_host\}', $FunctionHostname -replace '\$\{function_path\}', $FunctionPath -replace '\$\{virtual_users\}', $VirtualUsers -replace '\$\{ramp_up_seconds\}', $RampUpSeconds -replace '\$\{test_duration_seconds\}', $TestDurationSeconds

# Save the parameterized JMeter file
$jmeterFilePath = "load-test.jmx"
$jmeterContent | Out-File -FilePath $jmeterFilePath -Encoding UTF8
Write-Host "JMeter file created: $jmeterFilePath" -ForegroundColor Green

Write-Host "Creating load test configuration with server-side metrics..." -ForegroundColor Green

# Get Application Insights resource dynamically from the resource group
Write-Host "Finding Application Insights resource..." -ForegroundColor Cyan
$appInsightsResource = az resource list --resource-group $ResourceGroupName --resource-type "Microsoft.Insights/components" --query "[0]" | ConvertFrom-Json

if (-not $appInsightsResource) {
    Write-Error "Could not find Application Insights resource in resource group: $ResourceGroupName"
    exit 1
}

$AppInsightsName = $appInsightsResource.name
$appInsightsId = $appInsightsResource.id

Write-Host "Application Insights Name: $AppInsightsName" -ForegroundColor Green
Write-Host "Application Insights ID: $appInsightsId" -ForegroundColor Green

# Get App Service Plan resource dynamically from the resource group
Write-Host "Finding App Service Plan resource..." -ForegroundColor Cyan
$appServicePlanResource = az resource list --resource-group $ResourceGroupName --resource-type "Microsoft.Web/serverfarms" --query "[0]" | ConvertFrom-Json

if (-not $appServicePlanResource) {
    Write-Error "Could not find App Service Plan resource in resource group: $ResourceGroupName"
    exit 1
}

$AppServicePlanName = $appServicePlanResource.name
$appServicePlanId = $appServicePlanResource.id

Write-Host "App Service Plan Name: $AppServicePlanName" -ForegroundColor Green
Write-Host "App Service Plan ID: $appServicePlanId" -ForegroundColor Green

# Create YAML configuration with server-side metrics
$configTemplate = Get-Content "load-test-config.yaml.tpl" -Raw
$configContent = $configTemplate -replace '\$\{test_id\}', $TestName -replace '\$\{display_name\}', "Function App Scale Test" -replace '\$\{description\}', "Load test to trigger autoscaling of Azure Functions" -replace '\$\{app_insights_id\}', $appInsightsId -replace '\$\{app_insights_name\}', $AppInsightsName -replace '\$\{app_service_plan_id\}', $appServicePlanId -replace '\$\{app_service_plan_name\}', $AppServicePlanName

# Save the configuration file
$configFilePath = "load-test-config.yaml"
$configContent | Out-File -FilePath $configFilePath -Encoding UTF8
Write-Host "Load test configuration created: $configFilePath" -ForegroundColor Green

Write-Host "Creating load test with configuration..." -ForegroundColor Cyan

# Create load test with YAML configuration
$createCommand = "az load test create --resource-group $ResourceGroupName --load-test-resource $LoadTestResourceName --test-id $TestName --load-test-config-file $configFilePath"

Write-Host "Command: $createCommand" -ForegroundColor Gray
Invoke-Expression $createCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "Load test created successfully with server-side metrics!" -ForegroundColor Green
    
    Write-Host "Configured server-side metrics:" -ForegroundColor Cyan
    Write-Host "  • Application Insights Resource: $AppInsightsName" -ForegroundColor White
    Write-Host "  • App Service Plan Resource: $AppServicePlanName" -ForegroundColor White
    Write-Host "  • Available Metrics:" -ForegroundColor White
    Write-Host "    - Request Rate & Response Time (App Insights)" -ForegroundColor Gray
    Write-Host "    - CPU Percentage (App Service Plan) - KEY SCALING METRIC" -ForegroundColor Yellow
    Write-Host "    - Memory Percentage (App Service Plan)" -ForegroundColor Gray
    Write-Host "    - Instance Count (Autoscaling from App Insights)" -ForegroundColor Gray
    Write-Host "    - Failed Request Rate & Exceptions (App Insights)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Load test is ready to run!" -ForegroundColor Green
    Write-Host "Portal: $($terraformOutput.load_test_portal_url.value)" -ForegroundColor Cyan
} else {
    Write-Host "Failed to create load test" -ForegroundColor Red
}