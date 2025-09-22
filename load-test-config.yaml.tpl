version: v0.1
testId: ${test_id}
displayName: ${display_name}
description: ${description}
engineInstances: 1

testPlan: load-test.jmx

appComponents:
  - resourceId: ${app_insights_id}
    resourceName: ${app_insights_name}
    resourceType: Microsoft.Insights/components
    kind: web
  - resourceId: ${app_service_plan_id}
    resourceName: ${app_service_plan_name}
    resourceType: Microsoft.Web/serverfarms
    kind: web

serverMetrics:
  - resourceId: ${app_service_plan_id}
    metricNamespace: Microsoft.Web/serverfarms
    metrics:
      - name: CpuPercentage
        aggregation: Average
      - name: MemoryPercentage  
        aggregation: Average
      - name: HttpQueueLength
        aggregation: Average
  - resourceId: ${app_insights_id}
    metricNamespace: Microsoft.Insights/components
    metrics:
      - name: requests/count
        aggregation: Count
      - name: requests/duration
        aggregation: Average
      - name: requests/failed
        aggregation: Count