# Camel K Installation Script for AKS
# This script installs Camel K operator and CLI tools on your AKS cluster

param(
    [Parameter(Mandatory=$false)]
    [string]$CamelKVersion = "1.12.1",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "camel-k",
    
    [Parameter(Mandatory=$false)]
    [switch]$InstallSamples
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

# Function to check kubectl connection
function Test-KubernetesConnection {
    Write-Info "Checking Kubernetes cluster connection..."
    
    try {
        $clusterInfo = kubectl cluster-info --request-timeout=10s 2>$null
        if ($clusterInfo) {
            Write-Success "Connected to Kubernetes cluster"
            
            # Get cluster nodes
            $nodes = kubectl get nodes --output json | ConvertFrom-Json
            Write-Info "Cluster has $($nodes.items.Count) nodes:"
            foreach ($node in $nodes.items) {
                $status = ($node.status.conditions | Where-Object { $_.type -eq "Ready" }).status
                Write-Info "  - $($node.metadata.name): $status"
            }
            return $true
        }
        else {
            throw "No cluster info received"
        }
    }
    catch {
        Write-Error "Cannot connect to Kubernetes cluster. Please ensure:"
        Write-Error "1. AKS cluster is running"
        Write-Error "2. kubectl is configured correctly (run: az aks get-credentials)"
        Write-Error "3. You have proper permissions"
        exit 1
    }
}

# Function to check if Camel K CLI is installed
function Test-CamelKCLI {
    Write-Info "Checking Camel K CLI installation..."
    
    try {
        $kamelVersion = kamel version 2>$null
        if ($kamelVersion -match "Camel K Client (\d+\.\d+\.\d+)") {
            $installedVersion = $matches[1]
            Write-Success "Camel K CLI version $installedVersion found"
            return $true
        }
    }
    catch {
        Write-Warning "Camel K CLI not found"
        return $false
    }
}

# Function to install Camel K CLI
function Install-CamelKCLI {
    param([string]$Version)
    
    Write-Info "Installing Camel K CLI version $Version..."
    
    try {
        # Create tools directory
        $toolsDir = "C:\tools\camelk"
        if (-not (Test-Path $toolsDir)) {
            New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        }
        
        # Download Camel K CLI for Windows
        $downloadUrl = "https://github.com/apache/camel-k/releases/download/v$Version/camel-k-client-$Version-windows-64bit.tar.gz"
        $downloadPath = "$toolsDir\camel-k-client-$Version-windows-64bit.tar.gz"
        
        Write-Info "Downloading Camel K CLI from: $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
        
        # Extract the archive
        Write-Info "Extracting Camel K CLI..."
        tar -xzf $downloadPath -C $toolsDir
        
        # Move the binary to the tools directory
        Move-Item "$toolsDir\kamel.exe" "$toolsDir\kamel.exe" -Force 2>$null
        
        # Add to PATH if not already there
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$toolsDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$toolsDir", "User")
            $env:PATH += ";$toolsDir"
            Write-Success "Added Camel K CLI to PATH"
        }
        
        # Clean up download
        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        
        Write-Success "Camel K CLI installed successfully"
    }
    catch {
        Write-Error "Failed to install Camel K CLI: $($_.Exception.Message)"
        Write-Info "Alternative: Download manually from https://github.com/apache/camel-k/releases"
        exit 1
    }
}

# Function to create namespace
function New-CamelKNamespace {
    param([string]$NamespaceName)
    
    Write-Info "Creating namespace '$NamespaceName'..."
    
    try {
        $existingNs = kubectl get namespace $NamespaceName --output json 2>$null
        if ($existingNs) {
            Write-Warning "Namespace '$NamespaceName' already exists"
            return
        }
        
        kubectl create namespace $NamespaceName
        Write-Success "Namespace '$NamespaceName' created successfully"
    }
    catch {
        Write-Error "Failed to create namespace: $($_.Exception.Message)"
        exit 1
    }
}

# Function to install Camel K operator
function Install-CamelKOperator {
    param([string]$NamespaceName)
    
    Write-Info "Installing Camel K operator in namespace '$NamespaceName'..."
    
    try {
        # Check if operator is already installed
        $existingOperator = kubectl get deployment camel-k-operator -n $NamespaceName --output json 2>$null
        if ($existingOperator) {
            Write-Warning "Camel K operator already installed in namespace '$NamespaceName'"
            return
        }
        
        # Install Camel K operator using kamel CLI
        Write-Info "This may take a few minutes..."
        kamel install --namespace $NamespaceName --wait
        
        Write-Success "Camel K operator installed successfully"
        
        # Verify installation
        Write-Info "Verifying Camel K operator installation..."
        $retries = 0
        $maxRetries = 30
        
        do {
            Start-Sleep 10
            $operatorPods = kubectl get pods -n $NamespaceName -l name=camel-k-operator --output json | ConvertFrom-Json
            $runningPods = ($operatorPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
            
            if ($runningPods -gt 0) {
                Write-Success "Camel K operator is running"
                break
            }
            
            $retries++
            Write-Info "Waiting for operator to be ready... ($retries/$maxRetries)"
        } while ($retries -lt $maxRetries)
        
        if ($retries -ge $maxRetries) {
            Write-Warning "Operator may not be fully ready yet. Check with: kubectl get pods -n $NamespaceName"
        }
    }
    catch {
        Write-Error "Failed to install Camel K operator: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create sample Camel K integration
function New-SampleIntegration {
    param([string]$NamespaceName)
    
    Write-Info "Creating sample Camel K integrations..."
    
    $samplesDir = "C:\temp\aks-quarkus-camelk-setup\sample-projects\camelk-samples"
    
    try {
        if (-not (Test-Path $samplesDir)) {
            New-Item -ItemType Directory -Path $samplesDir -Force | Out-Null
        }
        
        # Create a simple timer integration
        $timerIntegration = @"
// Simple Timer Integration
import org.apache.camel.builder.RouteBuilder;

public class TimerRoute extends RouteBuilder {
    @Override
    public void configure() throws Exception {
        from("timer:tick?period=10000")
            .setBody(constant("Hello from Camel K on AKS! Time: " + System.currentTimeMillis()))
            .log("$${body}");
    }
}
"@
        
        $timerFile = "$samplesDir\TimerRoute.java"
        Set-Content -Path $timerFile -Value $timerIntegration -Encoding UTF8
        
        # Create a REST API integration
        $restIntegration = @"
// REST API Integration
import org.apache.camel.builder.RouteBuilder;

public class RestApiRoute extends RouteBuilder {
    @Override
    public void configure() throws Exception {
        // Configure REST
        restConfiguration()
            .component("netty-http")
            .host("0.0.0.0")
            .port(8080);
        
        // REST endpoint
        rest("/api")
            .get("/hello")
                .to("direct:hello")
            .get("/health")
                .to("direct:health");
        
        // Routes
        from("direct:hello")
            .setBody(constant("{\"message\": \"Hello from Camel K REST API on AKS!\"}"))
            .setHeader("Content-Type", constant("application/json"));
            
        from("direct:health")
            .setBody(constant("{\"status\": \"UP\", \"service\": \"camel-k-rest\"}"))
            .setHeader("Content-Type", constant("application/json"));
    }
}
"@
        
        $restFile = "$samplesDir\RestApiRoute.java"
        Set-Content -Path $restFile -Value $restIntegration -Encoding UTF8
        
        # Create a Quarkus integration
        $quarkusIntegration = @"
// Quarkus Camel Integration
// camel-k: dependency=camel-quarkus-timer
// camel-k: dependency=camel-quarkus-log

import org.apache.camel.builder.RouteBuilder;

public class QuarkusRoute extends RouteBuilder {
    @Override
    public void configure() throws Exception {
        from("timer:quarkus?period=15000")
            .setBody(simple("Quarkus + Camel K integration running on AKS! Counter: $${header.CamelTimerCounter}"))
            .log("Quarkus Route: $${body}");
    }
}
"@
        
        $quarkusFile = "$samplesDir\QuarkusRoute.java"
        Set-Content -Path $quarkusFile -Value $quarkusIntegration -Encoding UTF8
        
        # Create deployment script
        $deployScript = @"
# Deploy Camel K Sample Integrations

Write-Host "Deploying Timer Integration..." -ForegroundColor Cyan
kamel run TimerRoute.java --namespace $NamespaceName

Write-Host "Deploying REST API Integration..." -ForegroundColor Cyan
kamel run RestApiRoute.java --namespace $NamespaceName

Write-Host "Deploying Quarkus Integration..." -ForegroundColor Cyan
kamel run QuarkusRoute.java --namespace $NamespaceName

Write-Host "Deployment commands sent. Check status with:" -ForegroundColor Green
Write-Host "  kubectl get integrations -n $NamespaceName" -ForegroundColor Yellow
Write-Host "  kamel get --namespace $NamespaceName" -ForegroundColor Yellow
"@
        
        $deployFile = "$samplesDir\deploy-samples.ps1"
        Set-Content -Path $deployFile -Value $deployScript -Encoding UTF8
        
        Write-Success "Sample integrations created at: $samplesDir"
        Write-Info "To deploy samples, run: $samplesDir\deploy-samples.ps1"
    }
    catch {
        Write-Warning "Failed to create sample integrations: $($_.Exception.Message)"
    }
}

# Function to verify Camel K installation
function Test-CamelKInstallation {
    param([string]$NamespaceName)
    
    Write-Info "Verifying Camel K installation..."
    
    try {
        # Check operator status
        $operatorStatus = kamel get --namespace $NamespaceName 2>$null
        if ($operatorStatus) {
            Write-Success "Camel K operator is responsive"
        }
        
        # Check integration platform
        $platform = kubectl get integrationplatform -n $NamespaceName --output json 2>$null | ConvertFrom-Json
        if ($platform.items.Count -gt 0) {
            $platformStatus = $platform.items[0].status.phase
            Write-Success "Integration Platform status: $platformStatus"
        }
        
        Write-Info "Installation verification completed"
        return $true
    }
    catch {
        Write-Warning "Could not fully verify installation: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
Write-Info "Starting Camel K installation on AKS..."
Write-Info "=========================================="

# Verify prerequisites
Test-KubernetesConnection

# Check and install Camel K CLI if needed
if (-not (Test-CamelKCLI)) {
    Install-CamelKCLI -Version $CamelKVersion
}

# Create namespace
New-CamelKNamespace -NamespaceName $Namespace

# Install Camel K operator
Install-CamelKOperator -NamespaceName $Namespace

# Verify installation
Test-CamelKInstallation -NamespaceName $Namespace

# Create samples if requested
if ($InstallSamples -or $PSBoundParameters.Count -eq 0) {
    New-SampleIntegration -NamespaceName $Namespace
}

Write-Success "Camel K installation completed successfully!"
Write-Info "=========================================="
Write-Info "Installed components:"
Write-Info "✓ Camel K CLI version $CamelKVersion"
Write-Info "✓ Camel K operator in namespace '$Namespace'"
Write-Info "✓ Sample integrations (if enabled)"
Write-Info ""
Write-Info "Useful commands:"
Write-Info "  kamel get --namespace $Namespace                    # List integrations"
Write-Info "  kubectl get pods -n $Namespace                      # Check pods"
Write-Info "  kamel logs <integration-name> --namespace $Namespace # View logs"
Write-Info ""
Write-Info "Next steps:"
Write-Info "1. Run './04-verify-setup.ps1' to verify complete installation"
Write-Info "2. Deploy sample integrations from: C:\temp\aks-quarkus-camelk-setup\sample-projects\camelk-samples"