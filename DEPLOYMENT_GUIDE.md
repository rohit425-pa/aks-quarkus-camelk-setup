# Deployment Guide - Complete AKS Deployment

**Date**: October 29, 2025  
**Project**: Enterprise AKS + Quarkus + Camel K  
**Status**: Ready for Container Build and Deployment

## Current Status

✅ **Completed**:
- AKS cluster operational (aks-quarkus-camelk-west)
- Azure Container Registry configured (aksquarkuscamelkwest234.azurecr.io)
- Camel K operator installed and ready
- HelloWorld application built successfully (camelpoc-1.0-SNAPSHOT.jar)
- All compatibility issues resolved

🔄 **Next Phase**: Container Build → Registry Push → Kubernetes Deployment

## Prerequisites Verification

Before proceeding, verify all components are ready:

```powershell
# 1. Verify AKS cluster connection
kubectl get nodes

# Expected output:
# NAME                                STATUS   ROLES   AGE   VERSION
# aks-nodepool1-xxxxx-vmss000000     Ready    agent   1h    v1.28.x

# 2. Verify Camel K operator
kubectl get pods -n camel-k

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# camel-k-operator-xxxxx             1/1     Running   0          1h

# 3. Verify ACR authentication
az acr login --name aksquarkuscamelkwest234

# Expected output:
# Login Succeeded

# 4. Verify application build
ls target/camelpoc-1.0-SNAPSHOT.jar

# Expected output:
# target/camelpoc-1.0-SNAPSHOT.jar
```

## Step-by-Step Deployment Guide

### Phase 1: Container Image Build

#### Step 1.1: Build Docker Image
```powershell
# Navigate to application directory
cd C:\temp\aks-quarkus-camelk-setup\helloworld-app

# Build the container image
docker build -f src/main/docker/Dockerfile.jvm -t helloworld-camel-quarkus:latest .
```

**Expected Output**:
```
[+] Building 45.2s (8/8) FINISHED
=> CACHED [1/7] FROM registry.access.redhat.com/ubi8/openjdk-17:1.20
=> CACHED [2/7] COPY --chown=185 target/quarkus-app/lib/ /deployments/lib/
=> CACHED [3/7] COPY --chown=185 target/quarkus-app/*.jar /deployments/
=> CACHED [4/7] COPY --chown=185 target/quarkus-app/app/ /deployments/app/
=> CACHED [5/7] COPY --chown=185 target/quarkus-app/quarkus/ /deployments/quarkus/
=> exporting to image
=> => naming to docker.io/library/helloworld-camel-quarkus:latest
```

#### Step 1.2: Verify Local Image
```powershell
# List the built image
docker images helloworld-camel-quarkus

# Test run locally (optional)
docker run -p 8080:8080 --rm helloworld-camel-quarkus:latest
```

**Verification Tests**:
```powershell
# In a new terminal, test the endpoints
curl http://localhost:8080/camelpoc
# Expected: "Hello from Camel POC!"

curl http://localhost:8080/q/health
# Expected: {"status":"UP","checks":[...]}

# Stop the container with Ctrl+C
```

### Phase 2: Azure Container Registry Push

#### Step 2.1: Tag Image for ACR
```powershell
# Tag the image for ACR
docker tag helloworld-camel-quarkus:latest aksquarkuscamelkwest234.azurecr.io/helloworld-camel-quarkus:v1.0

# Also tag as latest
docker tag helloworld-camel-quarkus:latest aksquarkuscamelkwest234.azurecr.io/helloworld-camel-quarkus:latest
```

#### Step 2.2: Push to ACR
```powershell
# Ensure ACR login
az acr login --name aksquarkuscamelkwest234

# Push versioned image
docker push aksquarkuscamelkwest234.azurecr.io/helloworld-camel-quarkus:v1.0

# Push latest tag
docker push aksquarkuscamelkwest234.azurecr.io/helloworld-camel-quarkus:latest
```

**Expected Output**:
```
The push refers to repository [aksquarkuscamelkwest234.azurecr.io/helloworld-camel-quarkus]
v1.0: digest: sha256:xxxxx size: 1234
latest: digest: sha256:xxxxx size: 1234
```

#### Step 2.3: Verify ACR Repository
```powershell
# List repositories in ACR
az acr repository list --name aksquarkuscamelkwest234 --output table

# Show tags for the repository
az acr repository show-tags --name aksquarkuscamelkwest234 --repository helloworld-camel-quarkus --output table
```

### Phase 3: Kubernetes Deployment

#### Step 3.1: Create Kubernetes Manifests

Create deployment directory and manifests:

```powershell
# Create Kubernetes manifests directory
mkdir k8s
cd k8s
```

**Deployment Manifest** (`k8s/deployment.yaml`):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-app
  labels:
    app: helloworld-app
    version: v1.0
spec:
  replicas: 1
  selector:
    matchLabels:
      app: helloworld-app
  template:
    metadata:
      labels:
        app: helloworld-app
        version: v1.0
    spec:
      containers:
      - name: helloworld-camel-quarkus
        image: aksquarkuscamelkwest234.azurecr.io/helloworld-camel-quarkus:v1.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: QUARKUS_HTTP_HOST
          value: "0.0.0.0"
        - name: QUARKUS_HTTP_PORT
          value: "8080"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /q/health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /q/health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Service Manifest** (`k8s/service.yaml`):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: helloworld-service
  labels:
    app: helloworld-app
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: helloworld-app
```

**ConfigMap for Application Properties** (`k8s/configmap.yaml`):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: helloworld-config
data:
  application.properties: |
    quarkus.http.host=0.0.0.0
    quarkus.http.port=8080
    quarkus.log.level=INFO
    quarkus.log.console.enable=true
    quarkus.log.console.format=%d{HH:mm:ss} %-5p [%c{2.}] (%t) %s%e%n
```

#### Step 3.2: Create Manifest Files

```powershell
# Create deployment.yaml
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-app
  labels:
    app: helloworld-app
    version: v1.0
spec:
  replicas: 1
  selector:
    matchLabels:
      app: helloworld-app
  template:
    metadata:
      labels:
        app: helloworld-app
        version: v1.0
    spec:
      containers:
      - name: helloworld-camel-quarkus
        image: aksquarkuscamelkwest234.azurecr.io/helloworld-camel-quarkus:v1.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: QUARKUS_HTTP_HOST
          value: "0.0.0.0"
        - name: QUARKUS_HTTP_PORT
          value: "8080"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /q/health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /q/health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
"@ | Out-File -FilePath "deployment.yaml" -Encoding UTF8

# Create service.yaml
@"
apiVersion: v1
kind: Service
metadata:
  name: helloworld-service
  labels:
    app: helloworld-app
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: helloworld-app
"@ | Out-File -FilePath "service.yaml" -Encoding UTF8
```

#### Step 3.3: Deploy to AKS

```powershell
# Apply the Kubernetes manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

**Expected Output**:
```
deployment.apps/helloworld-app created
service/helloworld-service created
```

#### Step 3.4: Monitor Deployment

```powershell
# Watch deployment rollout
kubectl rollout status deployment/helloworld-app

# Check pod status
kubectl get pods -l app=helloworld-app

# Check service status
kubectl get service helloworld-service
```

**Wait for External IP**:
```powershell
# Monitor until EXTERNAL-IP is assigned (may take 2-5 minutes)
kubectl get service helloworld-service --watch

# Example output progression:
# NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
# helloworld-service   LoadBalancer   10.0.123.45    <pending>     80:32000/TCP   30s
# helloworld-service   LoadBalancer   10.0.123.45    20.1.2.3      80:32000/TCP   2m
```

### Phase 4: Application Testing

#### Step 4.1: Get Service Endpoint
```powershell
# Get the external IP address
$EXTERNAL_IP = kubectl get service helloworld-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo "Application URL: http://$EXTERNAL_IP"
```

#### Step 4.2: Test Application Endpoints

```powershell
# Test main endpoint
curl "http://$EXTERNAL_IP/camelpoc"
# Expected: "Hello from Camel POC!"

# Test health endpoint
curl "http://$EXTERNAL_IP/q/health"
# Expected: {"status":"UP","checks":[...]}

# Test readiness probe
curl "http://$EXTERNAL_IP/q/health/ready"
# Expected: {"status":"UP","checks":[...]}

# Test liveness probe
curl "http://$EXTERNAL_IP/q/health/live"
# Expected: {"status":"UP","checks":[...]}

# Test metrics endpoint
curl "http://$EXTERNAL_IP/q/metrics"
# Expected: Prometheus metrics output

# Test OpenAPI documentation
# Open in browser: http://$EXTERNAL_IP/q/swagger-ui
```

#### Step 4.3: Test POST Endpoint

```powershell
# Test POST endpoint with JSON payload
$jsonPayload = @{
    message = "Hello from AKS!"
    timestamp = (Get-Date).ToString()
} | ConvertTo-Json

curl -X POST "http://$EXTERNAL_IP/camelpoc" `
     -H "Content-Type: application/json" `
     -d $jsonPayload
```

### Phase 5: Monitoring and Validation

#### Step 5.1: Check Pod Logs
```powershell
# Get pod name
$POD_NAME = kubectl get pods -l app=helloworld-app -o jsonpath='{.items[0].metadata.name}'

# View logs
kubectl logs $POD_NAME

# Follow logs in real-time
kubectl logs -f $POD_NAME
```

#### Step 5.2: Application Metrics
```powershell
# Check resource usage
kubectl top pod $POD_NAME

# Describe pod for detailed status
kubectl describe pod $POD_NAME
```

#### Step 5.3: Verify Camel Routes
```powershell
# Check if Camel timer route is working (should see log messages every 30 seconds)
kubectl logs $POD_NAME | grep "Hello from Camel K"
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Image Pull Errors
```powershell
# Symptoms: Pod stuck in ImagePullBackOff
kubectl describe pod $POD_NAME

# Solution: Verify ACR integration
az aks check-acr --resource-group rg-aks-quarkus-camelk-west --name aks-quarkus-camelk-west --acr aksquarkuscamelkwest234
```

#### Issue 2: Application Not Starting
```powershell
# Check pod events
kubectl describe pod $POD_NAME

# Check application logs
kubectl logs $POD_NAME

# Common causes:
# - Java memory issues (increase memory limits)
# - Port binding issues (verify HTTP configuration)
# - Health check timeouts (increase initialDelaySeconds)
```

#### Issue 3: Service Not Accessible
```powershell
# Verify service endpoints
kubectl get endpoints helloworld-service

# Check if LoadBalancer is supported
kubectl describe service helloworld-service

# Alternative: Use NodePort for testing
kubectl patch service helloworld-service -p '{"spec":{"type":"NodePort"}}'
```

### Health Check Commands

```powershell
# Full health check script
function Test-Application {
    $service = kubectl get service helloworld-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    if ($service) {
        Write-Host "Testing application endpoints..."
        Write-Host "Main endpoint: $(curl -s "http://$service/camelpoc")"
        Write-Host "Health check: $(curl -s "http://$service/q/health" | ConvertFrom-Json | Select-Object status)"
        Write-Host "Application URL: http://$service"
    } else {
        Write-Host "Service external IP not yet assigned"
    }
}

Test-Application
```

## Cleanup Instructions

### Temporary Cleanup (Keep Infrastructure)
```powershell
# Remove application deployment only
kubectl delete -f k8s/

# Verify cleanup
kubectl get all
```

### Complete Cleanup (Remove All Resources)
```powershell
# Delete AKS cluster
az aks delete --resource-group rg-aks-quarkus-camelk-west --name aks-quarkus-camelk-west --yes --no-wait

# Delete resource group (removes everything)
az group delete --name rg-aks-quarkus-camelk-west --yes --no-wait
```

## Next Steps After Deployment

### 1. Production Readiness
- [ ] Configure horizontal pod autoscaling
- [ ] Set up monitoring with Prometheus/Grafana
- [ ] Implement ingress controller with SSL termination
- [ ] Configure backup and disaster recovery

### 2. CI/CD Integration
- [ ] Set up GitHub Actions or Azure DevOps pipeline
- [ ] Implement automated testing
- [ ] Configure blue-green or canary deployments
- [ ] Set up automated security scanning

### 3. Advanced Features
- [ ] Implement distributed tracing with Jaeger
- [ ] Add service mesh (Istio) integration
- [ ] Configure advanced networking policies
- [ ] Implement centralized logging

## Success Criteria

✅ **Deployment Success Indicators**:
- Pod status: Running
- Service status: LoadBalancer with external IP
- Health checks: All endpoints responding
- Application endpoints: Accessible from internet
- Camel routes: Executing successfully
- Logs: No critical errors

🎯 **Performance Targets**:
- Application startup: < 30 seconds
- Response time: < 2 seconds
- Memory usage: < 400MB
- CPU usage: < 50% under normal load

This deployment guide provides a complete path from the current state (successful Maven build) to a fully functional application running on AKS with external access and monitoring capabilities.