param(
    [Parameter(Mandatory=$false)]
    [string]$CamelKVersion = "2.2.0",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "camel-k"
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Apache Camel K Installation on AKS" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# Function to check command success
function Test-CommandSuccess {
    param($LastExitCode, $ErrorMessage)
    if ($LastExitCode -ne 0) {
        Write-Host "[ERROR] $ErrorMessage" -ForegroundColor Red
        return $false
    }
    return $true
}

# Check Kubernetes connection
Write-Host "Checking Kubernetes cluster connection..." -ForegroundColor Yellow
kubectl cluster-info --request-timeout=10s | Out-Null
if (-not (Test-CommandSuccess $LASTEXITCODE "Cannot connect to Kubernetes cluster")) {
    Write-Host "[ERROR] Please ensure:" -ForegroundColor Red
    Write-Host "  1. AKS cluster is running" -ForegroundColor Red
    Write-Host "  2. kubectl is configured correctly" -ForegroundColor Red
    Write-Host "  3. You have proper permissions" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Connected to Kubernetes cluster" -ForegroundColor Green

# Show cluster info
Write-Host "Cluster information:" -ForegroundColor Cyan
kubectl get nodes -o wide

# Create namespace for Camel K
Write-Host "`nCreating namespace '$Namespace'..." -ForegroundColor Yellow
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
if (Test-CommandSuccess $LASTEXITCODE "Failed to create namespace") {
    Write-Host "[SUCCESS] Namespace '$Namespace' created/verified" -ForegroundColor Green
}

# Download and install Camel K CLI (kamel)
Write-Host "Installing Camel K CLI..." -ForegroundColor Yellow
$kamelUrl = "https://github.com/apache/camel-k/releases/download/v$CamelKVersion/camel-k-client-$CamelKVersion-windows-64bit.tar.gz"
$kamelPath = "C:\tools\kamel.exe"

# Create tools directory if it doesn't exist
if (-not (Test-Path "C:\tools")) {
    New-Item -ItemType Directory -Path "C:\tools" -Force | Out-Null
}

# Download and extract kamel CLI
Write-Host "[INFO] Downloading Camel K CLI v$CamelKVersion..." -ForegroundColor Cyan
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $kamelUrl -OutFile "camel-k-client.tar.gz"
    
    # Extract using tar (available in Windows 10+)
    tar -xzf "camel-k-client.tar.gz"
    Move-Item "kamel.exe" $kamelPath -Force
    Remove-Item "camel-k-client.tar.gz" -Force
    
    # Add to PATH for current session
    $env:PATH += ";C:\tools"
    
    Write-Host "[SUCCESS] Camel K CLI installed successfully" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to download/install Camel K CLI: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify kamel CLI
Write-Host "Verifying Camel K CLI installation..." -ForegroundColor Yellow
& $kamelPath version
if (Test-CommandSuccess $LASTEXITCODE "Camel K CLI verification failed") {
    Write-Host "[SUCCESS] Camel K CLI is working" -ForegroundColor Green
}

# Install Camel K operator
Write-Host "`nInstalling Camel K operator..." -ForegroundColor Yellow
& $kamelPath install --namespace $Namespace
if (Test-CommandSuccess $LASTEXITCODE "Failed to install Camel K operator") {
    Write-Host "[SUCCESS] Camel K operator installation initiated" -ForegroundColor Green
}

# Wait for operator to be ready
Write-Host "Waiting for Camel K operator to be ready..." -ForegroundColor Yellow
$timeout = 300  # 5 minutes
$elapsed = 0
$interval = 10

do {
    Start-Sleep -Seconds $interval
    $elapsed += $interval
    
    $operatorStatus = kubectl get pods -n $Namespace -l name=camel-k-operator -o jsonpath="{.items[*].status.phase}" 2>$null
    
    if ($operatorStatus -eq "Running") {
        Write-Host "[SUCCESS] Camel K operator is running" -ForegroundColor Green
        break
    }
    
    Write-Host "[INFO] Waiting for operator... ($elapsed/$timeout seconds)" -ForegroundColor Cyan
    
    if ($elapsed -ge $timeout) {
        Write-Host "[WARNING] Timeout waiting for operator. Check status manually:" -ForegroundColor Yellow
        Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor Yellow
        break
    }
} while ($true)

# Show Camel K status
Write-Host "`nCamel K installation status:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
kubectl get IntegrationPlatform -n $Namespace 2>$null

# Create a simple test integration
Write-Host "`nCreating sample Camel K integration..." -ForegroundColor Yellow

$sampleIntegration = @"
// Simple Hello World Camel K integration
from('timer:hello?period=10000')
    .setBody(constant('Hello World from Camel K!'))
    .log('${body}')
"@

# Save to file
$sampleIntegration | Out-File -FilePath "hello-world.groovy" -Encoding UTF8

# Deploy the integration
Write-Host "[INFO] Deploying sample integration..." -ForegroundColor Cyan
& $kamelPath run hello-world.groovy --namespace $Namespace
if (Test-CommandSuccess $LASTEXITCODE "Failed to deploy sample integration") {
    Write-Host "[SUCCESS] Sample integration deployed" -ForegroundColor Green
}

# Create REST API integration
Write-Host "`nCreating REST API integration..." -ForegroundColor Yellow

$restIntegration = @"
// Simple REST API with Camel K
from('netty-http:http://0.0.0.0:8080/hello')
    .setBody(simple('{"message": "Hello from Camel K REST API!", "timestamp": "${date:now:yyyy-MM-dd HH:mm:ss}"}'))
    .setHeader('Content-Type', constant('application/json'))
"@

# Save REST integration
$restIntegration | Out-File -FilePath "rest-api.groovy" -Encoding UTF8

# Deploy REST integration
Write-Host "[INFO] Deploying REST API integration..." -ForegroundColor Cyan
& $kamelPath run rest-api.groovy --namespace $Namespace
if (Test-CommandSuccess $LASTEXITCODE "Failed to deploy REST integration") {
    Write-Host "[SUCCESS] REST API integration deployed" -ForegroundColor Green
}

# Show running integrations
Write-Host "`nRunning integrations:" -ForegroundColor Cyan
& $kamelPath get --namespace $Namespace

Write-Host "`n===========================================" -ForegroundColor Green
Write-Host "Camel K Installation Completed!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

Write-Host "Installation Summary:" -ForegroundColor Cyan
Write-Host "  Camel K Version: $CamelKVersion" -ForegroundColor White
Write-Host "  Namespace: $Namespace" -ForegroundColor White
Write-Host "  CLI Location: $kamelPath" -ForegroundColor White

Write-Host "`nSample Integrations Deployed:" -ForegroundColor Cyan
Write-Host "  1. hello-world.groovy - Timer-based logging" -ForegroundColor White
Write-Host "  2. rest-api.groovy - HTTP REST API" -ForegroundColor White

Write-Host "`nUseful Commands:" -ForegroundColor Cyan
Write-Host "  kamel get -n $Namespace                   # List integrations" -ForegroundColor White
Write-Host "  kamel log hello-world -n $Namespace       # View integration logs" -ForegroundColor White
Write-Host "  kamel delete hello-world -n $Namespace    # Delete integration" -ForegroundColor White
Write-Host "  kubectl get pods -n $Namespace            # View pods" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Check integration status: kamel get -n $Namespace" -ForegroundColor White
Write-Host "2. View logs: kamel log hello-world -n $Namespace" -ForegroundColor White
Write-Host "3. Test REST API once running: kubectl port-forward -n $Namespace svc/rest-api 8080:80" -ForegroundColor White
Write-Host "4. Setup monitoring: .\scripts\03-setup-monitoring.ps1" -ForegroundColor White

# Clean up temporary files
Remove-Item "hello-world.groovy" -ErrorAction SilentlyContinue
Remove-Item "rest-api.groovy" -ErrorAction SilentlyContinue