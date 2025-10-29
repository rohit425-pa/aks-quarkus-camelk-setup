# Enterprise-Grade Setup Verification Script
# This script verifies that AKS, Quarkus, and Camel K are properly installed and configured

param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "camel-k"
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

function Write-Header([String] $Message) {
    Write-Host ""
    Write-ColorOutput "Magenta" "=========================================="
    Write-ColorOutput "Magenta" $Message
    Write-ColorOutput "Magenta" "=========================================="
}

# Function to verify Azure CLI and connection
function Test-AzureConnection {
    Write-Header "Verifying Azure Connection"
    
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Success "Connected to Azure"
            Write-Info "  Account: $($account.user.name)"
            Write-Info "  Subscription: $($account.name)"
            Write-Info "  Tenant: $($account.tenantId)"
        } else {
            throw "Not connected"
        }
    }
    catch {
        Write-Error "Not connected to Azure. Run 'az login' first."
        return $false
    }
    return $true
}

# Function to verify AKS cluster
function Test-AKSCluster {
    Write-Header "Verifying AKS Cluster"
    
    try {
        # Check kubectl connection
        $clusterInfo = kubectl cluster-info --request-timeout=10s 2>$null
        if (-not $clusterInfo) {
            throw "Cannot connect to cluster"
        }
        Write-Success "Connected to Kubernetes cluster"
        
        # Get cluster details
        $context = kubectl config current-context 2>$null
        Write-Info "  Current context: $context"
        
        # Check nodes
        $nodes = kubectl get nodes --output json | ConvertFrom-Json
        Write-Success "Cluster has $($nodes.items.Count) nodes:"
        foreach ($node in $nodes.items) {
            $status = ($node.status.conditions | Where-Object { $_.type -eq "Ready" }).status
            $version = $node.status.nodeInfo.kubeletVersion
            Write-Info "  - $($node.metadata.name): $status (Kubernetes $version)"
        }
        
        # Check cluster version
        $version = kubectl version --output json 2>$null | ConvertFrom-Json
        Write-Info "  Server version: $($version.serverVersion.gitVersion)"
        
    }
    catch {
        Write-Error "AKS cluster verification failed: $($_.Exception.Message)"
        return $false
    }
    return $true
}

# Function to verify Java installation
function Test-JavaInstallation {
    Write-Header "Verifying Java Installation"
    
    try {
        $javaVersion = java -version 2>&1
        if ($javaVersion -match "version `"(\d+)") {
            $version = $matches[1]
            Write-Success "Java $version is installed"
            
            # Get JAVA_HOME
            $javaHome = $env:JAVA_HOME
            if ($javaHome) {
                Write-Info "  JAVA_HOME: $javaHome"
            } else {
                Write-Warning "  JAVA_HOME not set"
            }
        } else {
            throw "Java version not detected"
        }
    }
    catch {
        Write-Error "Java verification failed: $($_.Exception.Message)"
        return $false
    }
    return $true
}

# Function to verify Maven installation
function Test-MavenInstallation {
    Write-Header "Verifying Maven Installation"
    
    try {
        $mavenOutput = mvn --version 2>&1
        if ($mavenOutput -match "Apache Maven (\d+\.\d+\.\d+)") {
            $version = $matches[1]
            Write-Success "Maven $version is installed"
        } else {
            throw "Maven version not detected"
        }
    }
    catch {
        Write-Error "Maven verification failed: $($_.Exception.Message)"
        return $false
    }
    return $true
}

# Function to verify Quarkus installation
function Test-QuarkusInstallation {
    Write-Header "Verifying Quarkus Installation"
    
    try {
        # Try Quarkus CLI first
        $quarkusVersion = quarkus --version 2>$null
        if ($quarkusVersion) {
            Write-Success "Quarkus CLI is installed"
            Write-Info "  Version: $quarkusVersion"
        } else {
            Write-Warning "Quarkus CLI not found"
        }
        
        # Check if sample project exists
        $sampleProject = "C:\temp\aks-quarkus-camelk-setup\sample-projects\quarkus-sample\quarkus-sample"
        if (Test-Path "$sampleProject\pom.xml") {
            Write-Success "Sample Quarkus project found"
        } else {
            Write-Warning "Sample Quarkus project not found"
        }
    }
    catch {
        Write-Error "Quarkus verification failed: $($_.Exception.Message)"
        return $false
    }
    return $true
}

# Function to verify Camel K installation
function Test-CamelKInstallation {
    param([string]$NamespaceName)
    
    Write-Header "Verifying Camel K Installation"
    
    try {
        # Check Camel K CLI
        $kamelVersion = kamel version 2>$null
        if ($kamelVersion -match "Camel K Client (\d+\.\d+\.\d+)") {
            $version = $matches[1]
            Write-Success "Camel K CLI version $version is installed"
        } else {
            Write-Error "Camel K CLI not found"
            return $false
        }
        
        # Check namespace exists
        $namespace = kubectl get namespace $NamespaceName --output json 2>$null
        if ($namespace) {
            Write-Success "Namespace '$NamespaceName' exists"
        } else {
            Write-Error "Namespace '$NamespaceName' not found"
            return $false
        }
        
        # Check Camel K operator
        $operator = kubectl get deployment camel-k-operator -n $NamespaceName --output json 2>$null
        if ($operator) {
            Write-Success "Camel K operator is deployed"
        } else {
            Write-Error "Camel K operator not found"
            return $false
        }
        
    }
    catch {
        Write-Error "Camel K verification failed: $($_.Exception.Message)"
        return $false
    }
    return $true
}

# Main execution
Write-Info "Starting setup verification..."

$azureOK = Test-AzureConnection
$aksOK = Test-AKSCluster
$javaOK = Test-JavaInstallation
$mavenOK = Test-MavenInstallation
$quarkusOK = Test-QuarkusInstallation
$camelkOK = Test-CamelKInstallation -NamespaceName $Namespace

Write-Header "Verification Summary"
if ($azureOK -and $aksOK -and $javaOK -and $mavenOK -and $quarkusOK -and $camelkOK) {
    Write-Success "All components verified successfully!"
} else {
    Write-Warning "Some components failed verification. Please check the output above."
}