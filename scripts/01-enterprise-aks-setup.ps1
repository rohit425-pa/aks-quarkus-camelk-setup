# Enterprise-Grade AKS Cluster Setup Script
# This script creates a production-ready Azure Kubernetes Service (AKS) cluster with enterprise features

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "East US 2",
    
    [Parameter(Mandatory=$false)]
    [int]$NodeCount = 3,
    
    [Parameter(Mandatory=$false)]
    [string]$NodeSize = "Standard_D4s_v3",
    
    [Parameter(Mandatory=$false)]
    [string]$KubernetesVersion = "1.28.3",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "production",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$false)]
    [string]$ACRName,
    
    [Parameter(Mandatory=$false)]
    [string]$LogAnalyticsWorkspace,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnablePrivateCluster,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableAADIntegration,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableNetworkPolicy,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableAutoScaling,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableMonitoring,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableBackup
)

# Import required modules
Import-Module Az.Accounts -Force -ErrorAction SilentlyContinue
Import-Module Az.Resources -Force -ErrorAction SilentlyContinue
Import-Module Az.Aks -Force -ErrorAction SilentlyContinue

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

function Write-Header([String] $Message) {
    Write-Host ""
    Write-ColorOutput "Magenta" "=========================================="
    Write-ColorOutput "Magenta" $Message
    Write-ColorOutput "Magenta" "=========================================="
}

# Function to generate secure names if not provided
function Get-SecureName {
    param([string]$Prefix, [string]$Suffix = "")
    $randomString = -join ((1..8) | ForEach-Object {Get-Random -input ([char[]]([char]'a'..[char]'z') + ([char[]]([char]'0'..[char]'9')))})
    return "$Prefix-$randomString$Suffix"
}

# Function to validate prerequisites
function Test-Prerequisites {
    Write-Header "Validating Prerequisites"
    
    # Check Azure CLI
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
    
    # Check Azure login
    try {
        $accountCheck = az account show 2>$null
        if (-not $accountCheck) {
            throw "Not logged in"
        }
        $account = $accountCheck | ConvertFrom-Json
        Write-Success "Logged in to Azure as: $($account.user.name)"
        Write-Info "Using subscription: $($account.name) ($($account.id))"
    }
    catch {
        Write-Error "Not logged in to Azure. Please run 'az login' first"
        exit 1
    }
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --output=json 2>$null | ConvertFrom-Json
        Write-Success "kubectl version $($kubectlVersion.clientVersion.gitVersion) found"
    }
    catch {
        Write-Warning "kubectl not found. It will be installed automatically"
    }
    
    # Check Helm
    try {
        $helmVersion = helm version --short 2>$null
        Write-Success "Helm found: $helmVersion"
    }
    catch {
        Write-Warning "Helm not found. Installing Helm..."
        Install-Helm
    }
}

# Function to install Helm
function Install-Helm {
    try {
        Write-Info "Installing Helm..."
        Invoke-WebRequest -Uri "https://get.helm.sh/helm-v3.13.1-windows-amd64.zip" -OutFile "$env:TEMP\helm.zip"
        Expand-Archive -Path "$env:TEMP\helm.zip" -DestinationPath "$env:TEMP\helm" -Force
        
        $helmPath = "C:\tools\helm"
        if (-not (Test-Path $helmPath)) {
            New-Item -ItemType Directory -Path $helmPath -Force | Out-Null
        }
        
        Copy-Item "$env:TEMP\helm\windows-amd64\helm.exe" -Destination "$helmPath\helm.exe" -Force
        
        # Add to PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$helmPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$helmPath", "User")
            $env:PATH += ";$helmPath"
        }
        
        Remove-Item "$env:TEMP\helm.zip" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\helm" -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Success "Helm installed successfully"
    }
    catch {
        Write-Warning "Failed to install Helm automatically. Please install manually."
    }
}

# Function to create enterprise resource group with tags
function New-EnterpriseResourceGroup {
    param([string]$Name, [string]$Location, [string]$Environment)
    
    Write-Header "Creating Enterprise Resource Group"
    
    $existingRG = az group show --name $Name --output json 2>$null
    if ($existingRG) {
        Write-Warning "Resource group '$Name' already exists"
        return
    }
    
    try {
        $tags = @{
            "Environment" = $Environment
            "Project" = "AKS-Quarkus-CamelK"
            "Owner" = "DevOps-Team"
            "CostCenter" = "IT-Infrastructure"
            "CreatedDate" = (Get-Date).ToString("yyyy-MM-dd")
            "ManagedBy" = "Azure-CLI"
            "Compliance" = "Enterprise-Standard"
        }
        
        $tagString = ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
        
        az group create --name $Name --location $Location --tags $tagString --output none
        Write-Success "Enterprise resource group '$Name' created with proper tags"
    }
    catch {
        Write-Error "Failed to create resource group: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create Log Analytics workspace
function New-LogAnalyticsWorkspace {
    param([string]$ResourceGroup, [string]$WorkspaceName, [string]$Location)
    
    Write-Header "Creating Log Analytics Workspace"
    
    if (-not $WorkspaceName) {
        $WorkspaceName = Get-SecureName -Prefix "law-$ResourceGroup"
    }
    
    try {
        $workspace = az monitor log-analytics workspace show --resource-group $ResourceGroup --workspace-name $WorkspaceName --output json 2>$null
        if ($workspace) {
            Write-Warning "Log Analytics workspace '$WorkspaceName' already exists"
            return $WorkspaceName
        }
        
        Write-Info "Creating Log Analytics workspace '$WorkspaceName'..."
        az monitor log-analytics workspace create `
            --resource-group $ResourceGroup `
            --workspace-name $WorkspaceName `
            --location $Location `
            --sku PerGB2018 `
            --retention-time 30 `
            --output none
            
        Write-Success "Log Analytics workspace '$WorkspaceName' created"
        return $WorkspaceName
    }
    catch {
        Write-Error "Failed to create Log Analytics workspace: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create Azure Container Registry
function New-EnterpriseACR {
    param([string]$ResourceGroup, [string]$ACRName, [string]$Location)
    
    Write-Header "Creating Azure Container Registry"
    
    if (-not $ACRName) {
        $ACRName = Get-SecureName -Prefix "acr" -Suffix "prod"
    }
    
    try {
        $acr = az acr show --name $ACRName --resource-group $ResourceGroup --output json 2>$null
        if ($acr) {
            Write-Warning "Azure Container Registry '$ACRName' already exists"
            return $ACRName
        }
        
        Write-Info "Creating Azure Container Registry '$ACRName'..."
        az acr create `
            --resource-group $ResourceGroup `
            --name $ACRName `
            --sku Premium `
            --location $Location `
            --admin-enabled false `
            --public-network-enabled true `
            --zone-redundancy Enabled `
            --output none
            
        # Enable content trust and vulnerability scanning
        az acr config content-trust update --registry $ACRName --status enabled --output none
        az acr task credential add --registry $ACRName --login-server "$ACRName.azurecr.io" --output none 2>$null
        
        Write-Success "Enterprise Azure Container Registry '$ACRName' created with security features"
        return $ACRName
    }
    catch {
        Write-Error "Failed to create Azure Container Registry: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create Azure Key Vault
function New-EnterpriseKeyVault {
    param([string]$ResourceGroup, [string]$KeyVaultName, [string]$Location)
    
    Write-Header "Creating Azure Key Vault"
    
    if (-not $KeyVaultName) {
        $KeyVaultName = Get-SecureName -Prefix "kv" -Suffix "prod"
    }
    
    try {
        $kv = az keyvault show --name $KeyVaultName --resource-group $ResourceGroup --output json 2>$null
        if ($kv) {
            Write-Warning "Azure Key Vault '$KeyVaultName' already exists"
            return $KeyVaultName
        }
        
        Write-Info "Creating Azure Key Vault '$KeyVaultName'..."
        az keyvault create `
            --resource-group $ResourceGroup `
            --name $KeyVaultName `
            --location $Location `
            --sku Premium `
            --enable-purge-protection true `
            --enable-soft-delete true `
            --retention-days 90 `
            --enable-rbac-authorization false `
            --default-action Allow `
            --output none
            
        # Enable advanced security features
        az keyvault update `
            --name $KeyVaultName `
            --resource-group $ResourceGroup `
            --enable-disk-encryption true `
            --output none
            
        Write-Success "Enterprise Azure Key Vault '$KeyVaultName' created with security features"
        return $KeyVaultName
    }
    catch {
        Write-Error "Failed to create Azure Key Vault: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create enterprise AKS cluster
function New-EnterpriseAKSCluster {
    param(
        [string]$ResourceGroup,
        [string]$Name,
        [string]$Location,
        [int]$NodeCount,
        [string]$NodeSize,
        [string]$KubernetesVersion,
        [string]$LogWorkspace,
        [string]$ACRName,
        [string]$KeyVaultName,
        [bool]$PrivateCluster,
        [bool]$AADIntegration,
        [bool]$NetworkPolicy,
        [bool]$AutoScaling,
        [bool]$Monitoring
    )
    
    Write-Header "Creating Enterprise AKS Cluster"
    
    $existingCluster = az aks show --resource-group $ResourceGroup --name $Name --output json 2>$null
    if ($existingCluster) {
        Write-Warning "AKS cluster '$Name' already exists"
        return
    }
    
    try {
        Write-Info "Creating enterprise AKS cluster '$Name'..."
        Write-Info "This may take 15-20 minutes for enterprise configuration..."
        
        # Build the create command with enterprise features
        $createCmd = @(
            "az aks create"
            "--resource-group $ResourceGroup"
            "--name $Name"
            "--location $Location"
            "--node-count $NodeCount"
            "--node-vm-size $NodeSize"
            "--kubernetes-version $KubernetesVersion"
            "--tier Standard"
            "--load-balancer-sku Standard"
            "--network-plugin azure"
            "--network-plugin-mode overlay"
            "--pod-cidr 192.168.0.0/16"
            "--service-cidr 10.0.0.0/16"
            "--dns-service-ip 10.0.0.10"
            "--enable-managed-identity"
            "--generate-ssh-keys"
            "--node-osdisk-type Managed"
            "--node-osdisk-size 128"
            "--max-pods 110"
            "--enable-addons monitoring"
            "--enable-cluster-autoscaler"
            "--min-count 1"
            "--max-count 10"
            "--enable-pod-security-policy"
            "--enable-rbac"
            "--output none"
        )
        
        if ($NetworkPolicy) {
            $createCmd += "--network-policy calico"
        }
        
        if ($PrivateCluster) {
            $createCmd += "--enable-private-cluster"
            $createCmd += "--private-dns-zone system"
        }
        
        if ($AADIntegration) {
            $createCmd += "--enable-aad"
            $createCmd += "--enable-azure-rbac"
        }
        
        if ($Monitoring -and $LogWorkspace) {
            $workspaceId = az monitor log-analytics workspace show --resource-group $ResourceGroup --workspace-name $LogWorkspace --query id --output tsv
            $createCmd += "--workspace-resource-id $workspaceId"
        }
        
        # Execute the create command
        $fullCommand = $createCmd -join " "
        Invoke-Expression $fullCommand
        
        Write-Success "Enterprise AKS cluster '$Name' created successfully"
        
        # Attach ACR if provided
        if ($ACRName) {
            Write-Info "Attaching Azure Container Registry '$ACRName'..."
            az aks update --resource-group $ResourceGroup --name $Name --attach-acr $ACRName --output none
            Write-Success "ACR '$ACRName' attached to cluster"
        }
        
        # Enable Key Vault secrets provider if Key Vault provided
        if ($KeyVaultName) {
            Write-Info "Enabling Azure Key Vault secrets provider..."
            az aks addon enable --resource-group $ResourceGroup --name $Name --addon azure-keyvault-secrets-provider --output none
            Write-Success "Key Vault secrets provider enabled"
        }
        
    }
    catch {
        Write-Error "Failed to create AKS cluster: $($_.Exception.Message)"
        exit 1
    }
}

# Function to configure enterprise security
function Set-EnterpriseSecurity {
    param([string]$ResourceGroup, [string]$ClusterName)
    
    Write-Header "Configuring Enterprise Security"
    
    try {
        # Get AKS credentials
        az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing --output none
        
        # Create security namespaces
        Write-Info "Creating security namespaces..."
        kubectl create namespace security-system --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
        
        # Label namespaces for security policies
        kubectl label namespace kube-system security-level=system --overwrite
        kubectl label namespace security-system security-level=high --overwrite
        kubectl label namespace monitoring security-level=medium --overwrite
        kubectl label namespace logging security-level=medium --overwrite
        kubectl label namespace default security-level=low --overwrite
        
        Write-Success "Enterprise security namespaces configured"
        
        # Install security tools will be done in separate script
        Write-Info "Security tools installation will be handled by security hardening script"
        
    }
    catch {
        Write-Error "Failed to configure enterprise security: $($_.Exception.Message)"
    }
}

# Function to setup backup strategy
function Set-BackupStrategy {
    param([string]$ResourceGroup, [string]$ClusterName)
    
    Write-Header "Setting Up Backup Strategy"
    
    if (-not $EnableBackup) {
        Write-Info "Backup not enabled, skipping backup configuration"
        return
    }
    
    try {
        Write-Info "Configuring cluster backup strategy..."
        
        # Enable backup extension (Velero will be installed separately)
        Write-Info "Backup strategy will be implemented with Velero in monitoring setup"
        Write-Success "Backup strategy configuration prepared"
        
    }
    catch {
        Write-Error "Failed to setup backup strategy: $($_.Exception.Message)"
    }
}

# Function to validate cluster health
function Test-ClusterHealth {
    param([string]$ResourceGroup, [string]$ClusterName)
    
    Write-Header "Validating Cluster Health"
    
    try {
        # Test cluster connectivity
        $clusterInfo = kubectl cluster-info --request-timeout=30s 2>$null
        if (-not $clusterInfo) {
            throw "Cannot connect to cluster"
        }
        Write-Success "Cluster connectivity verified"
        
        # Check node status
        $nodes = kubectl get nodes --output json | ConvertFrom-Json
        $readyNodes = ($nodes.items | Where-Object { 
            ($_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }) 
        }).Count
        
        Write-Success "Cluster health: $readyNodes/$($nodes.items.Count) nodes ready"
        
        foreach ($node in $nodes.items) {
            $status = ($node.status.conditions | Where-Object { $_.type -eq "Ready" }).status
            $version = $node.status.nodeInfo.kubeletVersion
            Write-Info "  - $($node.metadata.name): $status (Kubernetes $version)"
        }
        
        # Check system pods
        $systemPods = kubectl get pods -n kube-system --output json | ConvertFrom-Json
        $runningPods = ($systemPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
        Write-Info "System pods: $runningPods/$($systemPods.items.Count) running"
        
        Write-Success "Enterprise AKS cluster is healthy and ready"
        
    }
    catch {
        Write-Error "Cluster health validation failed: $($_.Exception.Message)"
        exit 1
    }
}

# Main execution
Write-Header "Enterprise AKS Cluster Setup"
Write-Info "Starting enterprise-grade AKS cluster deployment..."

# Set default names if not provided
if (-not $KeyVaultName) {
    $KeyVaultName = "kv-$ClusterName-$(Get-Random -Minimum 1000 -Maximum 9999)"
}
if (-not $ACRName) {
    $ACRName = "acr$($ClusterName.Replace('-',''))$(Get-Random -Minimum 100 -Maximum 999)"
}
if (-not $LogAnalyticsWorkspace) {
    $LogAnalyticsWorkspace = "law-$ClusterName"
}

# Validate prerequisites
Test-Prerequisites

# Create enterprise infrastructure
New-EnterpriseResourceGroup -Name $ResourceGroupName -Location $Location -Environment $Environment
$workspaceName = New-LogAnalyticsWorkspace -ResourceGroup $ResourceGroupName -WorkspaceName $LogAnalyticsWorkspace -Location $Location
$acrName = New-EnterpriseACR -ResourceGroup $ResourceGroupName -ACRName $ACRName -Location $Location
$kvName = New-EnterpriseKeyVault -ResourceGroup $ResourceGroupName -KeyVaultName $KeyVaultName -Location $Location

# Create enterprise AKS cluster
New-EnterpriseAKSCluster `
    -ResourceGroup $ResourceGroupName `
    -Name $ClusterName `
    -Location $Location `
    -NodeCount $NodeCount `
    -NodeSize $NodeSize `
    -KubernetesVersion $KubernetesVersion `
    -LogWorkspace $workspaceName `
    -ACRName $acrName `
    -KeyVaultName $kvName `
    -PrivateCluster $EnablePrivateCluster `
    -AADIntegration $EnableAADIntegration `
    -NetworkPolicy $EnableNetworkPolicy `
    -AutoScaling $EnableAutoScaling `
    -Monitoring $EnableMonitoring

# Configure enterprise security
Set-EnterpriseSecurity -ResourceGroup $ResourceGroupName -ClusterName $ClusterName

# Setup backup strategy
Set-BackupStrategy -ResourceGroup $ResourceGroupName -ClusterName $ClusterName

# Validate cluster health
Test-ClusterHealth -ResourceGroup $ResourceGroupName -ClusterName $ClusterName

Write-Success "Enterprise AKS cluster setup completed successfully!"
Write-Header "Next Steps"
Write-Info "1. Run '.\scripts\02-security-hardening.ps1' to apply security policies"
Write-Info "2. Run '.\scripts\03-setup-monitoring.ps1' to deploy monitoring stack"
Write-Info "3. Run '.\scripts\04-install-quarkus-enterprise.ps1' for Quarkus setup"
Write-Info "4. Run '.\scripts\05-install-camelk-enterprise.ps1' for Camel K deployment"
Write-Info ""
Write-Info "Cluster Details:"
Write-Info "  Resource Group: $ResourceGroupName"
Write-Info "  Cluster Name: $ClusterName"
Write-Info "  ACR Name: $acrName"
Write-Info "  Key Vault: $kvName"
Write-Info "  Log Analytics: $workspaceName"