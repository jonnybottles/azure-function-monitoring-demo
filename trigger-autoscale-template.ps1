# Get the function URL (will be dynamically replaced by Terraform output)
$url = "${function_app_trigger_url}"

# Test the URL first to ensure it's accessible
Write-Host "Testing Function App URL: $url" -ForegroundColor Yellow
try {
    $testResponse = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 10
    Write-Host "Function App is responding successfully!" -ForegroundColor Green
    $responseText = $testResponse.ToString()
    $preview = $responseText.Substring(0, [Math]::Min(100, $responseText.Length))
    Write-Host "Response preview: $preview..." -ForegroundColor Gray
} catch {
    Write-Host "Error: Function App is not responding" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please check that the Function App is deployed and running." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Starting load test with 100 requests..." -ForegroundColor Cyan

# Simple approach: send requests in smaller batches for faster execution
$successCount = 0
$errorCount = 0
$totalRequests = 100

# Send requests in batches of 10 for better performance
for ($batch = 1; $batch -le 10; $batch++) {
    Write-Host "Batch $batch/10 (requests $($($batch-1)*10+1)-$($batch*10))..." -ForegroundColor Yellow
    
    # Send 10 concurrent requests per batch
    $batchJobs = @()
    for ($i = 1; $i -le 10; $i++) {
        $batchJobs += Start-Job -ScriptBlock {
            param($uri)
            try {
                $response = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 10
                return "Success"
            } catch {
                return "Error: $($_.Exception.Message)"
            }
        } -ArgumentList $url
    }
    
    # Wait for this batch to complete
    $batchResults = $batchJobs | Wait-Job | Receive-Job
    $batchJobs | Remove-Job
    
    # Count results
    $batchSuccess = ($batchResults | Where-Object { $_ -eq "Success" }).Count
    $batchErrors = $batchResults.Count - $batchSuccess
    $successCount += $batchSuccess
    $errorCount += $batchErrors
    
    Write-Host "  Batch completed: $batchSuccess success, $batchErrors errors" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Load Test Summary ===" -ForegroundColor Cyan
Write-Host "Total requests sent: $totalRequests" -ForegroundColor White
Write-Host "Successful responses: $successCount" -ForegroundColor Green
Write-Host "Failed/timeout requests: $errorCount" -ForegroundColor Red

if ($errorCount -gt 0) {
    Write-Host ""
    Write-Host "Note: Some requests failed/timed out. This is normal during cold starts." -ForegroundColor Yellow
    Write-Host "The successful requests should still trigger autoscaling." -ForegroundColor Yellow
}

Write-Host "Load test completed! Check your Azure Monitor workbook for autoscaling activity." -ForegroundColor Green