param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$false)]
    [int]$NodeCount = 3,
    
    [Parameter(Mandatory=$false)]
    [string]$NodeSize = "Standard_D4s_v3",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "production"
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Fixed Enterprise AKS Cluster Setup" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# Function to check command success
function Test-CommandSuccess {
    param($LastExitCode, $ErrorMessage)
    if ($LastExitCode -ne 0) {
        Write-Host "[ERROR] $ErrorMessage" -ForegroundColor Red
        exit 1
    }
}

# Test Azure login
Write-Host "Checking Azure login..." -ForegroundColor Yellow
$loginCheck = az account show 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

$accountInfo = $loginCheck | ConvertFrom-Json
Write-Host "[SUCCESS] Logged in as: $($accountInfo.user.name)" -ForegroundColor Green
Write-Host "[INFO] Using subscription: $($accountInfo.name)" -ForegroundColor Cyan

# Check provider registration status
Write-Host "Checking provider registrations..." -ForegroundColor Yellow
$containerServiceStatus = az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv
$containerRegistryStatus = az provider show --namespace Microsoft.ContainerRegistry --query registrationState -o tsv

if ($containerServiceStatus -ne "Registered") {
    Write-Host "[INFO] Container Service provider is: $containerServiceStatus" -ForegroundColor Yellow
    Write-Host "[INFO] Registering Microsoft.ContainerService provider..." -ForegroundColor Yellow
    az provider register --namespace Microsoft.ContainerService
}

if ($containerRegistryStatus -ne "Registered") {
    Write-Host "[INFO] Container Registry provider is: $containerRegistryStatus" -ForegroundColor Yellow
    Write-Host "[INFO] Registering Microsoft.ContainerRegistry provider..." -ForegroundColor Yellow
    az provider register --namespace Microsoft.ContainerRegistry
}

# Wait for registrations to complete
Write-Host "[INFO] Waiting for provider registrations to complete..." -ForegroundColor Yellow
do {
    Start-Sleep -Seconds 10
    $containerServiceStatus = az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv
    $containerRegistryStatus = az provider show --namespace Microsoft.ContainerRegistry --query registrationState -o tsv
    Write-Host "[INFO] ContainerService: $containerServiceStatus, ContainerRegistry: $containerRegistryStatus" -ForegroundColor Cyan
} while ($containerServiceStatus -ne "Registered" -or $containerRegistryStatus -ne "Registered")

Write-Host "[SUCCESS] All providers registered successfully" -ForegroundColor Green

# Create AKS cluster with correct parameters
Write-Host "Creating AKS cluster '$ClusterName'..." -ForegroundColor Yellow
Write-Host "[INFO] Configuration:" -ForegroundColor Cyan
Write-Host "[INFO]   - Node Count: $NodeCount" -ForegroundColor Cyan
Write-Host "[INFO]   - Node Size: $NodeSize" -ForegroundColor Cyan
Write-Host "[INFO]   - Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "[INFO]   - Location: $Location" -ForegroundColor Cyan
Write-Host "[INFO] This may take 10-15 minutes..." -ForegroundColor Yellow

az aks create `
    --resource-group $ResourceGroupName `
    --name $ClusterName `
    --node-count $NodeCount `
    --node-vm-size $NodeSize `
    --location $Location `
    --enable-addons monitoring `
    --generate-ssh-keys `
    --enable-cluster-autoscaler `
    --min-count 1 `
    --max-count 5 `
    --network-plugin azure `
    --tags Environment=$Environment Project=AKS-Quarkus-CamelK CreatedDate=$(Get-Date -Format "yyyy-MM-dd")

Test-CommandSuccess $LASTEXITCODE "Failed to create AKS cluster"
Write-Host "[SUCCESS] AKS cluster '$ClusterName' created successfully" -ForegroundColor Green

# Get AKS credentials
Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName --overwrite-existing
Test-CommandSuccess $LASTEXITCODE "Failed to get AKS credentials"
Write-Host "[SUCCESS] kubectl configured for AKS cluster '$ClusterName'" -ForegroundColor Green

# Test cluster connectivity
Write-Host "Testing cluster connectivity..." -ForegroundColor Yellow
kubectl get nodes
if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Cluster is accessible and nodes are ready" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Cluster connectivity test failed, but this might be temporary" -ForegroundColor Yellow
}

# Create Azure Container Registry
$acrName = ($ClusterName -replace '[^a-zA-Z0-9]', '').ToLower() + (Get-Random -Maximum 1000)
Write-Host "Creating Azure Container Registry '$acrName'..." -ForegroundColor Yellow

az acr create `
    --resource-group $ResourceGroupName `
    --name $acrName `
    --sku Basic `
    --location $Location `
    --tags Environment=$Environment Project=AKS-Quarkus-CamelK CreatedDate=$(Get-Date -Format "yyyy-MM-dd")

Test-CommandSuccess $LASTEXITCODE "Failed to create Azure Container Registry"
Write-Host "[SUCCESS] Azure Container Registry '$acrName' created" -ForegroundColor Green

# Attach ACR to AKS
Write-Host "Attaching ACR to AKS cluster..." -ForegroundColor Yellow
az aks update --name $ClusterName --resource-group $ResourceGroupName --attach-acr $acrName
Test-CommandSuccess $LASTEXITCODE "Failed to attach ACR to AKS cluster"
Write-Host "[SUCCESS] ACR '$acrName' attached to cluster" -ForegroundColor Green

Write-Host "===========================================" -ForegroundColor Green
Write-Host "AKS Cluster Setup Completed Successfully!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

Write-Host "Cluster Details:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Cluster Name: $ClusterName" -ForegroundColor White
Write-Host "  ACR Name: $acrName" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  Node Count: $NodeCount" -ForegroundColor White
Write-Host "  Node Size: $NodeSize" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Run kubectl get nodes to verify cluster" -ForegroundColor White
Write-Host "2. Install Quarkus development environment" -ForegroundColor White
Write-Host "3. Deploy Camel K operator" -ForegroundColor White
Write-Host "4. Install monitoring stack" -ForegroundColor White

Write-Host "`nAccess your cluster:" -ForegroundColor Cyan
Write-Host "  kubectl get nodes" -ForegroundColor White
Write-Host "  kubectl get pods --all-namespaces" -ForegroundColor White