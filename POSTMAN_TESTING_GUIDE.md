# Postman Testing Guide - HelloWorld Camel Quarkus Application

**Application URL**: http://4.246.33.120  
**Date**: October 29, 2025  
**Status**: Live and Operational

## 🚀 Quick Setup for Postman

### 1. Create New Collection in Postman
1. Open Postman
2. Click "New" → "Collection"
3. Name it: "HelloWorld Camel Quarkus - AKS"
4. Description: "Testing enterprise AKS deployed Quarkus + Camel application"

### 2. Set Collection Variables
Create these variables at the collection level:
- **Variable Name**: `base_url`
- **Current Value**: `http://4.246.33.120`

## 📋 Test Cases to Create

### Test Case 1: GET - Main Application Endpoint
```
Method: GET
URL: {{base_url}}/camelpoc
Headers: (none required)
Description: Tests the main GET endpoint that calls external API
```

**Expected Response**:
- Status: 200 OK
- Content-Type: application/json
- Body: JSON object with UserDetailsOutput array

### Test Case 2: POST - JSON Processing Endpoint
```
Method: POST
URL: {{base_url}}/camelpoc
Headers: 
  Content-Type: application/json
Body (raw JSON):
{
  "message": "Hello from Postman!",
  "timestamp": "{{$timestamp}}",
  "testId": "{{$randomUUID}}"
}
```

**Expected Response**:
- Status: 200 OK
- Content-Type: application/json
- Body: Processed response with your input data

### Test Case 3: Health Check - Overall Health
```
Method: GET
URL: {{base_url}}/q/health
Headers: (none required)
Description: Kubernetes health check endpoint
```

**Expected Response**:
- Status: 200 OK
- Content-Type: application/json
- Body: {"status": "UP", "checks": [...]}

### Test Case 4: Liveness Probe
```
Method: GET
URL: {{base_url}}/q/health/live
Headers: (none required)
Description: Kubernetes liveness probe endpoint
```

### Test Case 5: Readiness Probe
```
Method: GET
URL: {{base_url}}/q/health/ready
Headers: (none required)
Description: Kubernetes readiness probe endpoint
```

## 📁 Complete Postman Collection JSON

Copy and import this JSON into Postman:

```json
{
	"info": {
		"name": "HelloWorld Camel Quarkus - AKS",
		"description": "Testing enterprise AKS deployed Quarkus + Apache Camel application",
		"schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
	},
	"variable": [
		{
			"key": "base_url",
			"value": "http://4.246.33.120",
			"type": "string"
		}
	],
	"item": [
		{
			"name": "Application Tests",
			"item": [
				{
					"name": "GET - Main Endpoint (External API Call)",
					"request": {
						"method": "GET",
						"header": [],
						"url": {
							"raw": "{{base_url}}/camelpoc",
							"host": ["{{base_url}}"],
							"path": ["camelpoc"]
						},
						"description": "Tests the main GET endpoint that calls httpbin.org and processes JSON data through Camel routes"
					},
					"response": []
				},
				{
					"name": "POST - JSON Processing",
					"request": {
						"method": "POST",
						"header": [
							{
								"key": "Content-Type",
								"value": "application/json"
							}
						],
						"body": {
							"mode": "raw",
							"raw": "{\n  \"message\": \"Hello from Postman!\",\n  \"timestamp\": \"{{$timestamp}}\",\n  \"testId\": \"{{$randomUUID}}\",\n  \"environment\": \"AKS Production\",\n  \"framework\": \"Quarkus + Apache Camel\"\n}"
						},
						"url": {
							"raw": "{{base_url}}/camelpoc",
							"host": ["{{base_url}}"],
							"path": ["camelpoc"]
						},
						"description": "Tests POST endpoint with JSON payload processing through Camel routes"
					},
					"response": []
				}
			]
		},
		{
			"name": "Health & Monitoring",
			"item": [
				{
					"name": "Health Check - Overall",
					"request": {
						"method": "GET",
						"header": [],
						"url": {
							"raw": "{{base_url}}/q/health",
							"host": ["{{base_url}}"],
							"path": ["q", "health"]
						},
						"description": "Overall application health status"
					},
					"response": []
				},
				{
					"name": "Liveness Probe",
					"request": {
						"method": "GET",
						"header": [],
						"url": {
							"raw": "{{base_url}}/q/health/live",
							"host": ["{{base_url}}"],
							"path": ["q", "health", "live"]
						},
						"description": "Kubernetes liveness probe endpoint"
					},
					"response": []
				},
				{
					"name": "Readiness Probe",
					"request": {
						"method": "GET",
						"header": [],
						"url": {
							"raw": "{{base_url}}/q/health/ready",
							"host": ["{{base_url}}"],
							"path": ["q", "health", "ready"]
						},
						"description": "Kubernetes readiness probe endpoint"
					},
					"response": []
				}
			]
		},
		{
			"name": "Load Testing",
			"item": [
				{
					"name": "Concurrent GET Requests",
					"request": {
						"method": "GET",
						"header": [],
						"url": {
							"raw": "{{base_url}}/camelpoc",
							"host": ["{{base_url}}"],
							"path": ["camelpoc"]
						},
						"description": "Use Collection Runner to send multiple concurrent requests"
					},
					"response": []
				},
				{
					"name": "Stress Test POST",
					"request": {
						"method": "POST",
						"header": [
							{
								"key": "Content-Type",
								"value": "application/json"
							}
						],
						"body": {
							"mode": "raw",
							"raw": "{\n  \"message\": \"Load test iteration {{$randomInt}}\",\n  \"timestamp\": \"{{$timestamp}}\",\n  \"testId\": \"{{$randomUUID}}\",\n  \"iteration\": \"{{$randomInt}}\"\n}"
						},
						"url": {
							"raw": "{{base_url}}/camelpoc",
							"host": ["{{base_url}}"],
							"path": ["camelpoc"]
						}
					},
					"response": []
				}
			]
		}
	]
}
```

## 🧪 Advanced Testing Scenarios

### 1. Response Time Testing
Add these tests to your requests in the "Tests" tab:

```javascript
// Test response time
pm.test("Response time is less than 2000ms", function () {
    pm.expect(pm.response.responseTime).to.be.below(2000);
});

// Test status code
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

// Test content type
pm.test("Content-Type is application/json", function () {
    pm.expect(pm.response.headers.get("Content-Type")).to.include("application/json");
});
```

### 2. JSON Response Validation
For the GET endpoint:

```javascript
pm.test("Response has UserDetailsOutput", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('UserDetailsOutput');
    pm.expect(jsonData.UserDetailsOutput).to.be.an('array');
    pm.expect(jsonData.UserDetailsOutput.length).to.be.greaterThan(0);
});
```

For the POST endpoint:

```javascript
pm.test("POST response contains input message", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.include("Hello from Postman!");
});
```

### 3. Health Check Validation
```javascript
pm.test("Health status is UP", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.status).to.eql("UP");
});

pm.test("Health checks exist", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('checks');
    pm.expect(jsonData.checks).to.be.an('array');
});
```

## 🔄 Load Testing with Postman

### Collection Runner Setup
1. Click on your collection
2. Click "Run" or use the Runner
3. Configure:
   - **Iterations**: 10-50 (start small)
   - **Delay**: 100ms between requests
   - **Data**: Upload a CSV file for different test data

### Sample Test Data CSV
Create a file called `test-data.csv`:
```csv
message,environment
"Test from iteration 1","Production"
"Test from iteration 2","Production"
"Load test message","AKS"
"Performance test","Kubernetes"
```

## 📊 Performance Benchmarks

### Expected Response Times
- **GET /camelpoc**: < 2 seconds (includes external API call)
- **POST /camelpoc**: < 1 second
- **Health endpoints**: < 500ms

### Expected Throughput
- **Concurrent Users**: 10-20 (single pod)
- **Requests per Second**: 5-10 (with external API dependency)

## 🔍 Monitoring During Tests

### View Application Logs
```powershell
# Watch logs in real-time
kubectl logs -f helloworld-app-7ffddb6bf5-rj4c8

# Check resource usage
kubectl top pod helloworld-app-7ffddb6bf5-rj4c8
```

### Monitor Pod Status
```powershell
# Watch pod status
kubectl get pods -l app=helloworld-app -w

# Check events
kubectl describe pod helloworld-app-7ffddb6bf5-rj4c8
```

## 🎯 Test Scenarios to Validate

### Functional Tests
- ✅ GET endpoint returns external API data
- ✅ POST endpoint processes JSON correctly
- ✅ Health endpoints return UP status
- ✅ Application handles concurrent requests

### Performance Tests
- ✅ Response times under load
- ✅ Memory usage during stress test
- ✅ CPU utilization patterns
- ✅ External API integration stability

### Error Handling Tests
- ❌ Invalid JSON payload (should return 400/500)
- ❌ Non-existent endpoints (should return 404)
- ❌ Large payload handling

## 🚀 Getting Started

1. **Copy the Collection JSON** above
2. **Import into Postman**: File → Import → Raw Text
3. **Set Environment**: Make sure `base_url` is set to `http://4.246.33.120`
4. **Run Individual Tests**: Click each request to test
5. **Run Collection**: Use Collection Runner for automated testing

Your application is ready for comprehensive testing! The external IP `4.246.33.120` is live and responding to all requests. 🎉