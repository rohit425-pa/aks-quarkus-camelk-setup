# Quarkus Development Environment Setup Script
# This script installs Java, Maven, and Quarkus CLI for development

param(
    [Parameter(Mandatory=$false)]
    [string]$JavaVersion = "17",
    
    [Parameter(Mandatory=$false)]
    [string]$MavenVersion = "3.9.5",
    
    [Parameter(Mandatory=$false)]
    [string]$QuarkusVersion = "3.5.0"
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

# Function to check if Chocolatey is installed
function Test-Chocolatey {
    Write-Info "Checking Chocolatey installation..."
    
    try {
        $chocoVersion = choco --version 2>$null
        if ($chocoVersion) {
            Write-Success "Chocolatey version $chocoVersion found"
            return $true
        }
    }
    catch {
        Write-Warning "Chocolatey not found"
        return $false
    }
}

# Function to install Chocolatey
function Install-Chocolatey {
    Write-Info "Installing Chocolatey package manager..."
    
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Success "Chocolatey installed successfully"
        
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Error "Failed to install Chocolatey: $($_.Exception.Message)"
        exit 1
    }
}

# Function to check if Java is installed
function Test-Java {
    param([string]$RequiredVersion)
    
    Write-Info "Checking Java installation..."
    
    try {
        $javaVersion = java -version 2>&1
        if ($javaVersion -match "version `"(\d+)") {
            $installedVersion = $matches[1]
            if ([int]$installedVersion -ge [int]$RequiredVersion) {
                Write-Success "Java $installedVersion found (required: $RequiredVersion+)"
                return $true
            }
            else {
                Write-Warning "Java $installedVersion found, but version $RequiredVersion+ is required"
                return $false
            }
        }
    }
    catch {
        Write-Warning "Java not found"
        return $false
    }
}

# Function to install Java
function Install-Java {
    param([string]$Version)
    
    Write-Info "Installing OpenJDK $Version..."
    
    try {
        choco install openjdk$Version -y
        Write-Success "OpenJDK $Version installed successfully"
        
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $env:JAVA_HOME = [System.Environment]::GetEnvironmentVariable("JAVA_HOME","Machine")
    }
    catch {
        Write-Error "Failed to install Java: $($_.Exception.Message)"
        exit 1
    }
}

# Function to check if Maven is installed
function Test-Maven {
    Write-Info "Checking Maven installation..."
    
    try {
        $mavenVersion = mvn --version 2>$null
        if ($mavenVersion -match "Apache Maven (\d+\.\d+\.\d+)") {
            $installedVersion = $matches[1]
            Write-Success "Maven $installedVersion found"
            return $true
        }
    }
    catch {
        Write-Warning "Maven not found"
        return $false
    }
}

# Function to install Maven
function Install-Maven {
    Write-Info "Installing Apache Maven..."
    
    try {
        choco install maven -y
        Write-Success "Maven installed successfully"
        
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Error "Failed to install Maven: $($_.Exception.Message)"
        exit 1
    }
}

# Function to check if Quarkus CLI is installed
function Test-QuarkusCLI {
    Write-Info "Checking Quarkus CLI installation..."
    
    try {
        $quarkusVersion = quarkus --version 2>$null
        if ($quarkusVersion) {
            Write-Success "Quarkus CLI found: $quarkusVersion"
            return $true
        }
    }
    catch {
        Write-Warning "Quarkus CLI not found"
        return $false
    }
}

# Function to install Quarkus CLI
function Install-QuarkusCLI {
    Write-Info "Installing Quarkus CLI..."
    
    try {
        # Install using JBang
        Write-Info "Installing JBang first (required for Quarkus CLI)..."
        choco install jbang -y
        
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Info "Installing Quarkus CLI via JBang..."
        jbang app install --fresh --force quarkus@quarkusio
        
        Write-Success "Quarkus CLI installed successfully"
    }
    catch {
        Write-Error "Failed to install Quarkus CLI: $($_.Exception.Message)"
        Write-Info "Alternative: You can create Quarkus projects using Maven archetype:"
        Write-Info "mvn io.quarkus.platform:quarkus-maven-plugin:$QuarkusVersion:create"
    }
}

# Function to create a sample Quarkus project
function New-SampleQuarkusProject {
    Write-Info "Creating a sample Quarkus project..."
    
    $projectDir = "C:\temp\aks-quarkus-camelk-setup\sample-projects\quarkus-sample"
    
    try {
        if (Test-Path $projectDir) {
            Write-Warning "Sample project directory already exists: $projectDir"
            return
        }
        
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        Set-Location $projectDir
        
        # Create project using Maven archetype as backup
        mvn io.quarkus.platform:quarkus-maven-plugin:$QuarkusVersion`:create `
            -DprojectGroupId=com.example `
            -DprojectArtifactId=quarkus-sample `
            -Dextensions="resteasy-reactive,resteasy-reactive-jackson" `
            -DbuildTool=maven
            
        Write-Success "Sample Quarkus project created at: $projectDir\quarkus-sample"
        Write-Info "To run the project:"
        Write-Info "  cd $projectDir\quarkus-sample"
        Write-Info "  mvn quarkus:dev"
    }
    catch {
        Write-Warning "Failed to create sample project: $($_.Exception.Message)"
    }
}

# Function to configure IDE support
function Install-IDEExtensions {
    Write-Info "Checking for VS Code and installing Quarkus extensions..."
    
    try {
        $codeVersion = code --version 2>$null
        if ($codeVersion) {
            Write-Success "VS Code found, installing Quarkus extensions..."
            
            # Install essential extensions for Quarkus development
            $extensions = @(
                "redhat.vscode-quarkus",
                "redhat.java",
                "vscjava.vscode-java-pack",
                "ms-kubernetes-tools.vscode-kubernetes-tools"
            )
            
            foreach ($extension in $extensions) {
                Write-Info "Installing extension: $extension"
                code --install-extension $extension --force
            }
            
            Write-Success "VS Code extensions installed"
        }
        else {
            Write-Info "VS Code not found. Consider installing it for better Quarkus development experience."
        }
    }
    catch {
        Write-Warning "Could not configure IDE extensions"
    }
}

# Main execution
Write-Info "Starting Quarkus development environment setup..."
Write-Info "=========================================="

# Check and install Chocolatey if needed
if (-not (Test-Chocolatey)) {
    Install-Chocolatey
}

# Check and install Java if needed
if (-not (Test-Java -RequiredVersion $JavaVersion)) {
    Install-Java -Version $JavaVersion
}

# Check and install Maven if needed
if (-not (Test-Maven)) {
    Install-Maven
}

# Check and install Quarkus CLI if needed
if (-not (Test-QuarkusCLI)) {
    Install-QuarkusCLI
}

# Configure IDE support
Install-IDEExtensions

# Create sample project
New-SampleQuarkusProject

Write-Success "Quarkus development environment setup completed successfully!"
Write-Info "=========================================="
Write-Info "Installed components:"
Write-Info "✓ Java OpenJDK $JavaVersion"
Write-Info "✓ Apache Maven"
Write-Info "✓ Quarkus CLI"
Write-Info "✓ VS Code extensions (if VS Code is available)"
Write-Info ""
Write-Info "Next steps:"
Write-Info "1. Run './03-install-camelk.ps1' to install Camel K on your AKS cluster"
Write-Info "2. Check the sample project at: C:\temp\aks-quarkus-camelk-setup\sample-projects\quarkus-sample"