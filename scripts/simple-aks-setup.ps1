# Simple Enterprise AKS Setup Script
# This script creates a production-ready Azure Kubernetes Service (AKS) cluster

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US 2",
    
    [Parameter(Mandatory=$false)]
    [int]$NodeCount = 3,
    
    [Parameter(Mandatory=$false)]
    [string]$NodeSize = "Standard_D4s_v3",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "production"
)

# Color output functions
function Write-Success([String] $Message) {
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Info([String] $Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warning([String] $Message) {
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error([String] $Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header([String] $Message) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Magenta
    Write-Host $Message -ForegroundColor Magenta
    Write-Host "==========================================" -ForegroundColor Magenta
}

# Function to check Azure login
function Test-AzureLogin {
    Write-Header "Checking Azure Login"
    
    try {
        $accountCheck = az account show 2>$null
        if (-not $accountCheck) {
            Write-Error "Not logged in to Azure. Please run 'az login' first"
            exit 1
        }
        $account = $accountCheck | ConvertFrom-Json
        Write-Success "Logged in to Azure as: $($account.user.name)"
        Write-Info "Using subscription: $($account.name) ($($account.id))"
        return $true
    }
    catch {
        Write-Error "Failed to check Azure login: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create resource group
function New-ResourceGroup {
    param([string]$Name, [string]$Location, [string]$Environment)
    
    Write-Header "Creating Resource Group"
    
    $existingRG = az group show --name $Name --output json 2>$null
    if ($existingRG) {
        Write-Warning "Resource group '$Name' already exists"
        return
    }
    
    try {
        Write-Info "Creating resource group '$Name' in '$Location'..."
        az group create --name $Name --location $Location --tags Environment=$Environment Project=AKS-Quarkus-CamelK CreatedDate=$(Get-Date -Format "yyyy-MM-dd") --output none
        Write-Success "Resource group '$Name' created successfully"
    }
    catch {
        Write-Error "Failed to create resource group: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create AKS cluster
function New-AKSCluster {
    param(
        [string]$ResourceGroup,
        [string]$Name,
        [string]$Location,
        [int]$NodeCount,
        [string]$NodeSize
    )
    
    Write-Header "Creating AKS Cluster"
    
    $existingCluster = az aks show --resource-group $ResourceGroup --name $Name --output json 2>$null
    if ($existingCluster) {
        Write-Warning "AKS cluster '$Name' already exists"
        return
    }
    
    try {
        Write-Info "Creating AKS cluster '$Name'..."
        Write-Info "Configuration:"
        Write-Info "  - Node Count: $NodeCount"
        Write-Info "  - Node Size: $NodeSize"
        Write-Info "  - Resource Group: $ResourceGroup"
        Write-Info "  - Location: $Location"
        Write-Info "This may take 10-15 minutes..."
        
        az aks create `
            --resource-group $ResourceGroup `
            --name $Name `
            --location $Location `
            --node-count $NodeCount `
            --node-vm-size $NodeSize `
            --enable-addons monitoring `
            --enable-cluster-autoscaler `
            --min-count 1 `
            --max-count 10 `
            --enable-rbac `
            --generate-ssh-keys `
            --output none
            
        Write-Success "AKS cluster '$Name' created successfully"
    }
    catch {
        Write-Error "Failed to create AKS cluster: $($_.Exception.Message)"
        exit 1
    }
}

# Function to get AKS credentials
function Get-AKSCredentials {
    param([string]$ResourceGroup, [string]$Name)
    
    Write-Header "Getting AKS Credentials"
    
    try {
        Write-Info "Getting AKS credentials and configuring kubectl..."
        az aks get-credentials --resource-group $ResourceGroup --name $Name --overwrite-existing --output none
        Write-Success "kubectl configured for AKS cluster '$Name'"
        
        # Test kubectl connection
        $nodes = kubectl get nodes --output json 2>$null | ConvertFrom-Json
        if ($nodes.items.Count -gt 0) {
            Write-Success "Successfully connected to cluster. Found $($nodes.items.Count) nodes:"
            foreach ($node in $nodes.items) {
                $status = ($node.status.conditions | Where-Object { $_.type -eq "Ready" }).status
                Write-Info "  - $($node.metadata.name): $status"
            }
        }
    }
    catch {
        Write-Error "Failed to get AKS credentials: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create Azure Container Registry
function New-AzureContainerRegistry {
    param([string]$ResourceGroup, [string]$Location)
    
    Write-Header "Creating Azure Container Registry"
    
    $acrName = "acr$($ClusterName.Replace('-','').ToLower())$(Get-Random -Minimum 100 -Maximum 999)"
    
    try {
        $acr = az acr show --name $acrName --resource-group $ResourceGroup --output json 2>$null
        if ($acr) {
            Write-Warning "Azure Container Registry '$acrName' already exists"
            return $acrName
        }
        
        Write-Info "Creating Azure Container Registry '$acrName'..."
        az acr create `
            --resource-group $ResourceGroup `
            --name $acrName `
            --sku Standard `
            --location $Location `
            --admin-enabled false `
            --output none
            
        Write-Success "Azure Container Registry '$acrName' created"
        
        # Attach ACR to AKS cluster
        Write-Info "Attaching ACR to AKS cluster..."
        az aks update --resource-group $ResourceGroup --name $ClusterName --attach-acr $acrName --output none
        Write-Success "ACR '$acrName' attached to cluster"
        
        return $acrName
    }
    catch {
        Write-Error "Failed to create Azure Container Registry: $($_.Exception.Message)"
        exit 1
    }
}

# Main execution
Write-Header "Enterprise AKS Cluster Setup"
Write-Info "Starting AKS cluster deployment..."

# Check Azure login
Test-AzureLogin

# Create resource group
New-ResourceGroup -Name $ResourceGroupName -Location $Location -Environment $Environment

# Create AKS cluster
New-AKSCluster -ResourceGroup $ResourceGroupName -Name $ClusterName -Location $Location -NodeCount $NodeCount -NodeSize $NodeSize

# Get AKS credentials
Get-AKSCredentials -ResourceGroup $ResourceGroupName -Name $ClusterName

# Create Azure Container Registry
$acrName = New-AzureContainerRegistry -ResourceGroup $ResourceGroupName -Location $Location

Write-Success "AKS cluster setup completed successfully!"
Write-Header "Next Steps"
Write-Info "1. Install Quarkus development environment"
Write-Info "2. Deploy Camel K operator"
Write-Info "3. Install monitoring stack"
Write-Info ""
Write-Info "Cluster Details:"
Write-Info "  Resource Group: $ResourceGroupName"
Write-Info "  Cluster Name: $ClusterName"
Write-Info "  ACR Name: $acrName"
Write-Info "  Location: $Location"
Write-Info ""
Write-Info "Access your cluster:"
Write-Info "  kubectl get nodes"
Write-Info "  kubectl get pods --all-namespaces"