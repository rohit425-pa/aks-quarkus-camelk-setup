# AKS Cluster Setup Script
# This script creates a new Azure Kubernetes Service (AKS) cluster

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [int]$NodeCount = 3,
    
    [Parameter(Mandatory=$false)]
    [string]$NodeSize = "Standard_DS2_v2",
    
    [Parameter(Mandatory=$false)]
    [string]$KubernetesVersion = "1.28.3"
)

# Color output functions
function Write-ColorOutput([String] $ForegroundColor, [String] $Message) {
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Write-Success([String] $Message) {
    Write-ColorOutput "Green" "✓ $Message"
}

function Write-Info([String] $Message) {
    Write-ColorOutput "Cyan" "ℹ $Message"
}

function Write-Warning([String] $Message) {
    Write-ColorOutput "Yellow" "⚠ $Message"
}

function Write-Error([String] $Message) {
    Write-ColorOutput "Red" "✗ $Message"
}

# Function to check if Azure CLI is installed and logged in
function Test-AzureCLI {
    Write-Info "Checking Azure CLI installation and login status..."
    
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        if (-not $azVersion) {
            throw "Azure CLI not found"
        }
        Write-Success "Azure CLI version $($azVersion.'azure-cli') found"
    }
    catch {
        Write-Error "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }
    
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if (-not $account) {
            throw "Not logged in"
        }
        Write-Success "Logged in to Azure as: $($account.user.name)"
        Write-Info "Using subscription: $($account.name) ($($account.id))"
    }
    catch {
        Write-Error "Not logged in to Azure. Please run 'az login' first"
        exit 1
    }
}

# Function to check if kubectl is installed
function Test-Kubectl {
    Write-Info "Checking kubectl installation..."
    
    try {
        $kubectlVersion = kubectl version --client --output=json 2>$null | ConvertFrom-Json
        Write-Success "kubectl version $($kubectlVersion.clientVersion.gitVersion) found"
    }
    catch {
        Write-Warning "kubectl not found. It will be installed automatically with AKS CLI tools"
    }
}

# Function to create resource group
function New-AzureResourceGroup {
    param([string]$Name, [string]$Location)
    
    Write-Info "Creating resource group '$Name' in '$Location'..."
    
    $existingRG = az group show --name $Name --output json 2>$null
    if ($existingRG) {
        Write-Warning "Resource group '$Name' already exists"
        return
    }
    
    try {
        az group create --name $Name --location $Location --output none
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
        [int]$NodeCount,
        [string]$NodeSize,
        [string]$KubernetesVersion
    )
    
    Write-Info "Creating AKS cluster '$Name'..."
    Write-Info "Configuration:"
    Write-Info "  - Node Count: $NodeCount"
    Write-Info "  - Node Size: $NodeSize"
    Write-Info "  - Kubernetes Version: $KubernetesVersion"
    Write-Info "  - Resource Group: $ResourceGroup"
    
    # Check if cluster already exists
    $existingCluster = az aks show --resource-group $ResourceGroup --name $Name --output json 2>$null
    if ($existingCluster) {
        Write-Warning "AKS cluster '$Name' already exists"
        return
    }
    
    try {
        Write-Info "This may take 10-15 minutes..."
        az aks create `
            --resource-group $ResourceGroup `
            --name $Name `
            --node-count $NodeCount `
            --node-vm-size $NodeSize `
            --kubernetes-version $KubernetesVersion `
            --enable-addons monitoring,http_application_routing `
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
    
    Write-Info "Getting AKS credentials and configuring kubectl..."
    
    try {
        az aks get-credentials --resource-group $ResourceGroup --name $Name --overwrite-existing
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

# Function to install AKS CLI tools
function Install-AKSTools {
    Write-Info "Installing AKS CLI tools (including kubectl)..."
    
    try {
        az aks install-cli
        Write-Success "AKS CLI tools installed successfully"
    }
    catch {
        Write-Warning "Failed to install AKS CLI tools automatically. You may need to install kubectl manually."
    }
}

# Main execution
Write-Info "Starting AKS cluster setup..."
Write-Info "=========================================="

# Validate prerequisites
Test-AzureCLI
Test-Kubectl

# Install AKS tools if needed
Install-AKSTools

# Create resources
New-AzureResourceGroup -Name $ResourceGroupName -Location $Location
New-AKSCluster -ResourceGroup $ResourceGroupName -Name $ClusterName -NodeCount $NodeCount -NodeSize $NodeSize -KubernetesVersion $KubernetesVersion
Get-AKSCredentials -ResourceGroup $ResourceGroupName -Name $ClusterName

Write-Success "AKS cluster setup completed successfully!"
Write-Info "=========================================="
Write-Info "Next steps:"
Write-Info "1. Run './02-install-quarkus.ps1' to set up Quarkus development environment"
Write-Info "2. Run './03-install-camelk.ps1' to install Camel K on your cluster"
Write-Info "3. Run './04-verify-setup.ps1' to verify all installations"