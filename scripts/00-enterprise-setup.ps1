# Enterprise AKS + Quarkus + Camel K Complete Setup Orchestrator
# This script orchestrates the complete enterprise setup process

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "config\enterprise-config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAKSSetup,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSecurity,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipMonitoring,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipQuarkus,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipCamelK,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipVerification,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
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

function Write-Banner {
    Write-Host ""
    Write-ColorOutput "Cyan" "╔══════════════════════════════════════════════════════════════╗"
    Write-ColorOutput "Cyan" "║                ENTERPRISE AKS SETUP                          ║"
    Write-ColorOutput "Cyan" "║            Quarkus + Camel K + Monitoring                    ║"
    Write-ColorOutput "Cyan" "║                                                              ║"
    Write-ColorOutput "Cyan" "║  Production-Ready • Secure • Compliant • Observable         ║"
    Write-ColorOutput "Cyan" "╚══════════════════════════════════════════════════════════════╝"
    Write-Host ""
}

# Function to validate configuration file
function Test-Configuration {
    param([string]$ConfigPath)
    
    Write-Header "Validating Configuration"
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        Write-Info "Creating sample configuration file..."
        
        $sampleConfig = @{
            azure = @{
                subscription = "your-subscription-id"
                location = "East US 2"
                environment = "production"
            }
            cluster = @{
                resourceGroupName = "rg-aks-prod-001"
                clusterName = "aks-prod-cluster-001"
                nodeCount = 3
                nodeSize = "Standard_D4s_v3"
                kubernetesVersion = "1.28.3"
            }
            security = @{
                enableAAD = $true
                enableRBAC = $true
                enableNetworkPolicy = $true
                keyVaultName = "kv-aks-prod-001"
            }
            monitoring = @{
                enablePrometheus = $true
                enableGrafana = $true
                enableJaeger = $true
                enableFluentd = $true
                enableVelero = $true
            }
            development = @{
                javaVersion = "17"
                enableEnterpriseExtensions = $true
                configureIDE = $true
            }
        }
        
        $configDir = Split-Path $ConfigPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        $sampleConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Write-Success "Sample configuration created: $ConfigPath"
        Write-Warning "Please edit the configuration file with your settings and run the script again."
        exit 1
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Success "Configuration file validated: $ConfigPath"
        
        # Validate required settings
        $requiredSettings = @(
            "azure.subscription",
            "azure.location",
            "cluster.resourceGroupName",
            "cluster.clusterName"
        )
        
        foreach ($setting in $requiredSettings) {
            $parts = $setting -split '\.'
            $value = $config
            foreach ($part in $parts) {
                $value = $value.$part
                if (-not $value) {
                    throw "Missing required setting: $setting"
                }
            }
        }
        
        Write-Success "All required configuration settings present"
        return $config
    }
    catch {
        Write-Error "Configuration validation failed: $($_.Exception.Message)"
        exit 1
    }
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    $prerequisites = @(
        @{ Name = "Azure CLI"; Command = "az version" },
        @{ Name = "kubectl"; Command = "kubectl version --client" },
        @{ Name = "Helm"; Command = "helm version" },
        @{ Name = "PowerShell"; Command = "$PSVersionTable.PSVersion" }
    )
    
    $allGood = $true
    
    foreach ($prereq in $prerequisites) {
        try {
            $null = Invoke-Expression $prereq.Command -ErrorAction Stop
            Write-Success "$($prereq.Name) is available"
        }
        catch {
            Write-Error "$($prereq.Name) is not available or not working"
            $allGood = $false
        }
    }
    
    # Check Azure login
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Success "Logged in to Azure as: $($account.user.name)"
        } else {
            throw "Not logged in"
        }
    }
    catch {
        Write-Error "Not logged in to Azure. Please run 'az login' first"
        $allGood = $false
    }
    
    if (-not $allGood) {
        Write-Error "Prerequisites check failed. Please install missing components."
        exit 1
    }
    
    Write-Success "All prerequisites satisfied"
}

# Function to create directory structure
function New-ProjectStructure {
    Write-Header "Creating Project Structure"
    
    $directories = @(
        "scripts",
        "config",
        "manifests",
        "reports",
        "logs",
        "sample-projects\quarkus-samples",
        "sample-projects\camelk-samples",
        "docs",
        "backup"
    )
    
    foreach ($dir in $directories) {
        $path = "C:\temp\aks-quarkus-camelk-setup\$dir"
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Success "Created directory: $dir"
        }
    }
}

# Function to execute setup step
function Invoke-SetupStep {
    param(
        [string]$StepName,
        [string]$ScriptPath,
        [hashtable]$Parameters,
        [bool]$Skip = $false
    )
    
    if ($Skip) {
        Write-Warning "Skipping $StepName (as requested)"
        return $true
    }
    
    Write-Header "Executing: $StepName"
    
    if ($DryRun) {
        Write-Info "DRY RUN: Would execute $ScriptPath with parameters:"
        foreach ($param in $Parameters.GetEnumerator()) {
            Write-Info "  -$($param.Key) $($param.Value)"
        }
        return $true
    }
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script not found: $ScriptPath"
        return $false
    }
    
    try {
        $paramString = ($Parameters.GetEnumerator() | ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }) -join " "
        $command = "& '$ScriptPath' $paramString"
        
        Write-Info "Executing: $command"
        $startTime = Get-Date
        
        Invoke-Expression $command
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            $duration = (Get-Date) - $startTime
            Write-Success "$StepName completed successfully (Duration: $($duration.ToString('mm\:ss')))"
            return $true
        } else {
            Write-Error "$StepName failed with exit code: $LASTEXITCODE"
            return $false
        }
    }
    catch {
        Write-Error "$StepName failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to generate setup report
function New-SetupReport {
    param(
        [object]$Config,
        [hashtable]$Results,
        [datetime]$StartTime
    )
    
    Write-Header "Generating Setup Report"
    
    $reportPath = "C:\temp\aks-quarkus-camelk-setup\reports"
    $reportFile = "$reportPath\enterprise-setup-report-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
    
    $totalDuration = (Get-Date) - $StartTime
    
    $report = @"
ENTERPRISE AKS + QUARKUS + CAMEL K SETUP REPORT
==============================================
Generated: $(Get-Date)
Duration: $($totalDuration.ToString('hh\:mm\:ss'))

CONFIGURATION:
Resource Group: $($Config.cluster.resourceGroupName)
Cluster Name: $($Config.cluster.clusterName)
Location: $($Config.azure.location)
Environment: $($Config.azure.environment)
Node Count: $($Config.cluster.nodeCount)
Node Size: $($Config.cluster.nodeSize)
Kubernetes Version: $($Config.cluster.kubernetesVersion)

SETUP RESULTS:
"@
    
    foreach ($result in $Results.GetEnumerator()) {
        $status = if ($result.Value) { "✓ SUCCESS" } else { "✗ FAILED" }
        $report += "`n$($result.Key): $status"
    }
    
    $successCount = ($Results.Values | Where-Object { $_ }).Count
    $totalCount = $Results.Count
    
    $report += @"

SUMMARY:
$successCount/$totalCount components completed successfully
Overall Status: $(if ($successCount -eq $totalCount) { "SUCCESS" } else { "PARTIAL/FAILED" })

NEXT STEPS:
"@
    
    if ($successCount -eq $totalCount) {
        $report += @"

1. ACCESS YOUR ENVIRONMENT:
   # Connect to cluster
   az aks get-credentials --resource-group $($Config.cluster.resourceGroupName) --name $($Config.cluster.clusterName)
   
   # Access Grafana dashboard
   kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80
   # Navigate to http://localhost:3000 (admin/admin123!)
   
   # Access Prometheus
   kubectl port-forward -n monitoring svc/prometheus-stack-prometheus 9090:9090
   
   # Access Jaeger tracing
   kubectl port-forward -n tracing svc/jaeger-query 16686:80

2. DEPLOY YOUR FIRST CAMEL K INTEGRATION:
   # Create a simple integration
   kamel run --namespace camel-k integration.java
   
   # Monitor integration
   kamel get --namespace camel-k
   kubectl get pods -n camel-k

3. MONITOR AND MAINTAIN:
   # Check cluster health
   kubectl get nodes
   kubectl get pods -A
   
   # Review monitoring
   # Access Grafana dashboards
   # Set up alerting channels
   
   # Schedule regular backups
   velero schedule create daily-backup --schedule="0 2 * * *" --include-namespaces camel-k

4. SECURITY REVIEW:
   # Review security policies
   kubectl get networkpolicies -A
   kubectl get podsecuritypolicies
   
   # Check RBAC
   kubectl get clusterroles | grep camel-k
   
   # Review secrets management
   kubectl get secretproviderclass -A

5. COST OPTIMIZATION:
   # Monitor resource usage
   kubectl top nodes
   kubectl top pods -A
   
   # Review Azure costs in portal
   # Consider reserved instances for long-term workloads
"@
    } else {
        $report += @"

FAILED COMPONENTS NEED ATTENTION:
"@
        foreach ($result in $Results.GetEnumerator()) {
            if (-not $result.Value) {
                $report += "`n- $($result.Key): Review logs and retry"
            }
        }
        
        $report += @"

REMEDIATION STEPS:
1. Review error logs in the logs directory
2. Check Azure portal for resource status
3. Verify permissions and quotas
4. Re-run failed components individually
5. Contact support if issues persist
"@
    }
    
    $report += @"

DOCUMENTATION:
- Main Documentation: README-Enterprise.md
- Troubleshooting Guide: docs/troubleshooting.md
- Operations Manual: docs/operations.md
- Security Guide: docs/security.md

SUPPORT:
- Azure Support: Azure portal
- Kubernetes Community: https://kubernetes.io/community/
- Camel K Community: https://camel.apache.org/camel-k/
- Quarkus Community: https://quarkus.io/community/

Report Generated: $(Get-Date)
Report Location: $reportFile
"@
    
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Success "Setup report generated: $reportFile"
    
    # Display summary
    Write-Header "Setup Summary"
    if ($successCount -eq $totalCount) {
        Write-Success "Enterprise setup completed successfully! ($successCount/$totalCount components)"
        Write-Info "Your AKS cluster with Quarkus and Camel K is ready for production use."
    } else {
        Write-Warning "Setup partially completed ($successCount/$totalCount components)"
        Write-Info "Please review the report and address any failed components."
    }
    
    Write-Info ""
    Write-Info "Quick access commands:"
    Write-Info "kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
    Write-Info "kubectl get pods -A"
    Write-Info "kamel get -n camel-k"
}

# Main execution
Write-Banner

$startTime = Get-Date
$setupResults = @{}

try {
    # Validate configuration
    $config = Test-Configuration -ConfigPath $ConfigFile
    
    # Check prerequisites
    Test-Prerequisites
    
    # Create project structure
    New-ProjectStructure
    
    # Step 1: AKS Infrastructure Setup
    $aksParams = @{
        ResourceGroupName = $config.cluster.resourceGroupName
        ClusterName = $config.cluster.clusterName
        Location = $config.azure.location
        NodeCount = $config.cluster.nodeCount
        NodeSize = $config.cluster.nodeSize
        KubernetesVersion = $config.cluster.kubernetesVersion
        Environment = $config.azure.environment
        EnablePrivateCluster = $config.security.enablePrivateCluster -eq $true
        EnableAADIntegration = $config.security.enableAAD -eq $true
        EnableNetworkPolicy = $config.security.enableNetworkPolicy -eq $true
        EnableAutoScaling = $true
        EnableMonitoring = $true
        EnableBackup = $true
    }
    
    $setupResults["AKS Infrastructure"] = Invoke-SetupStep `
        -StepName "AKS Infrastructure Setup" `
        -ScriptPath ".\scripts\01-enterprise-aks-setup.ps1" `
        -Parameters $aksParams `
        -Skip $SkipAKSSetup
    
    # Step 2: Security Hardening
    $securityParams = @{
        ResourceGroupName = $config.cluster.resourceGroupName
        ClusterName = $config.cluster.clusterName
        KeyVaultName = $config.security.keyVaultName
        Environment = $config.azure.environment
        EnableNetworkPolicies = $config.security.enableNetworkPolicy -eq $true
        EnablePodSecurityStandards = $true
        EnableFalco = $true
        EnableImageScanning = $true
    }
    
    $setupResults["Security Hardening"] = Invoke-SetupStep `
        -StepName "Security Hardening" `
        -ScriptPath ".\scripts\02-security-hardening.ps1" `
        -Parameters $securityParams `
        -Skip $SkipSecurity
    
    # Step 3: Monitoring Setup
    $monitoringParams = @{
        ResourceGroupName = $config.cluster.resourceGroupName
        ClusterName = $config.cluster.clusterName
        EnablePrometheus = $config.monitoring.enablePrometheus -eq $true
        EnableGrafana = $config.monitoring.enableGrafana -eq $true
        EnableJaeger = $config.monitoring.enableJaeger -eq $true
        EnableFluentd = $config.monitoring.enableFluentd -eq $true
        EnableAlertManager = $true
        EnableVelero = $config.monitoring.enableVelero -eq $true
    }
    
    $setupResults["Monitoring Stack"] = Invoke-SetupStep `
        -StepName "Monitoring and Observability" `
        -ScriptPath ".\scripts\03-setup-monitoring.ps1" `
        -Parameters $monitoringParams `
        -Skip $SkipMonitoring
    
    # Step 4: Quarkus Setup
    $quarkusParams = @{
        JavaVersion = $config.development.javaVersion
        EnableEnterpriseExtensions = $config.development.enableEnterpriseExtensions -eq $true
        ConfigureIDE = $config.development.configureIDE -eq $true
    }
    
    $setupResults["Quarkus Environment"] = Invoke-SetupStep `
        -StepName "Quarkus Development Environment" `
        -ScriptPath ".\scripts\02-install-quarkus.ps1" `
        -Parameters $quarkusParams `
        -Skip $SkipQuarkus
    
    # Step 5: Camel K Deployment
    $camelkParams = @{
        Namespace = "camel-k"
        EnableMonitoring = $true
        EnableSecurity = $true
        InstallSamples = $true
    }
    
    $setupResults["Camel K Platform"] = Invoke-SetupStep `
        -StepName "Camel K Enterprise Platform" `
        -ScriptPath ".\scripts\03-install-camelk.ps1" `
        -Parameters $camelkParams `
        -Skip $SkipCamelK
    
    # Step 6: Verification
    $verificationParams = @{
        Namespace = "camel-k"
    }
    
    $setupResults["Verification"] = Invoke-SetupStep `
        -StepName "Setup Verification" `
        -ScriptPath ".\scripts\04-verify-setup.ps1" `
        -Parameters $verificationParams `
        -Skip $SkipVerification
    
    # Generate final report
    New-SetupReport -Config $config -Results $setupResults -StartTime $startTime
    
}
catch {
    Write-Error "Enterprise setup failed: $($_.Exception.Message)"
    Write-Info "Check the logs directory for detailed error information"
    exit 1
}

Write-Success "Enterprise AKS + Quarkus + Camel K setup orchestration completed!"
Write-Info "Review the generated report for next steps and access information."