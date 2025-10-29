# 🚀 Quick Postman Testing Reference

## Application Details
- **Live URL**: `http://4.246.33.120`
- **Status**: ✅ OPERATIONAL
- **Framework**: Quarkus + Apache Camel
- **Platform**: Azure Kubernetes Service (AKS)

## 📥 Import Postman Collection

### Option 1: Import JSON File
1. Download: `HelloWorld-Camel-AKS.postman_collection.json`
2. Open Postman → File → Import
3. Select the downloaded JSON file

### Option 2: Import by Link (if shared)
```
Collection Link: [Copy the collection JSON content]
```

## 🎯 Quick Test Commands

### 1. Main GET Endpoint
```
Method: GET
URL: http://4.246.33.120/camelpoc
Expected: JSON with UserDetailsOutput array
```

### 2. POST with JSON
```
Method: POST
URL: http://4.246.33.120/camelpoc
Content-Type: application/json
Body:
{
  "message": "Hello from Postman!",
  "timestamp": "2025-10-29T11:15:00Z",
  "testId": "test-123"
}
```

### 3. Health Check
```
Method: GET
URL: http://4.246.33.120/q/health
Expected: {"status": "UP"}
```

## 🔄 Collection Runner Setup

### For Load Testing:
1. Select collection → Run
2. Set iterations: 10-50
3. Set delay: 100-500ms
4. Monitor response times

### Expected Performance:
- GET /camelpoc: < 3 seconds
- POST /camelpoc: < 2 seconds  
- Health checks: < 500ms

## 📊 Test Categories Included

### ✅ Functional Tests
- Main application endpoints
- JSON processing
- External API integration
- Health monitoring

### ✅ Performance Tests  
- Response time validation
- Load testing scenarios
- Concurrent request handling

### ✅ Error Handling
- Invalid endpoints (404)
- Malformed JSON
- Error response validation

## 🎉 Ready to Test!

Your enterprise AKS application is live and ready for comprehensive testing with Postman!