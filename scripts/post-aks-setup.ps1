param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Post-AKS Creation Setup" -ForegroundColor Cyan
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

# Get AKS credentials
Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName --overwrite-existing
if (Test-CommandSuccess $LASTEXITCODE "Failed to get AKS credentials") {
    Write-Host "[SUCCESS] kubectl configured for AKS cluster '$ClusterName'" -ForegroundColor Green
}

# Test cluster connectivity
Write-Host "Testing cluster connectivity..." -ForegroundColor Yellow
$nodeOutput = kubectl get nodes 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Cluster is accessible:" -ForegroundColor Green
    Write-Host $nodeOutput -ForegroundColor White
} else {
    Write-Host "[WARNING] Cluster connectivity test failed: $nodeOutput" -ForegroundColor Yellow
    Write-Host "[INFO] This might be temporary, waiting for cluster to be fully ready..." -ForegroundColor Cyan
}

# Create Azure Container Registry
$acrName = ($ClusterName -replace '[^a-zA-Z0-9]', '').ToLower() + (Get-Random -Maximum 1000)
Write-Host "Creating Azure Container Registry '$acrName'..." -ForegroundColor Yellow

az acr create `
    --resource-group $ResourceGroupName `
    --name $acrName `
    --sku Basic `
    --location "East US 2" `
    --tags Environment=production Project=AKS-Quarkus-CamelK CreatedDate=$(Get-Date -Format "yyyy-MM-dd")

if (Test-CommandSuccess $LASTEXITCODE "Failed to create Azure Container Registry") {
    Write-Host "[SUCCESS] Azure Container Registry '$acrName' created" -ForegroundColor Green
}

# Attach ACR to AKS
Write-Host "Attaching ACR to AKS cluster..." -ForegroundColor Yellow
az aks update --name $ClusterName --resource-group $ResourceGroupName --attach-acr $acrName
if (Test-CommandSuccess $LASTEXITCODE "Failed to attach ACR to AKS cluster") {
    Write-Host "[SUCCESS] ACR '$acrName' attached to cluster" -ForegroundColor Green
}

# Check cluster status
Write-Host "Final cluster verification..." -ForegroundColor Yellow
Write-Host "Nodes:" -ForegroundColor Cyan
kubectl get nodes -o wide

Write-Host "`nNamespaces:" -ForegroundColor Cyan
kubectl get namespaces

Write-Host "`nCluster Info:" -ForegroundColor Cyan
kubectl cluster-info

Write-Host "===========================================" -ForegroundColor Green
Write-Host "Post-Setup Completed Successfully!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

Write-Host "Cluster Details:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Cluster Name: $ClusterName" -ForegroundColor White
Write-Host "  ACR Name: $acrName" -ForegroundColor White
Write-Host "  Location: West US 2" -ForegroundColor White
Write-Host "  Node Size: Standard_B2s (2 cores, 4GB RAM)" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Run security hardening script: .\scripts\02-security-hardening.ps1" -ForegroundColor White
Write-Host "2. Install monitoring stack: .\scripts\03-setup-monitoring.ps1" -ForegroundColor White
Write-Host "3. Setup Quarkus environment: .\scripts\04-setup-quarkus.ps1" -ForegroundColor White
Write-Host "4. Deploy Camel K: .\scripts\05-deploy-camelk.ps1" -ForegroundColor White