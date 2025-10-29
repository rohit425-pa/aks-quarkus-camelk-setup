param(
    [Parameter(Mandatory=$false)]
    [string]$JavaVersion = "17",
    
    [Parameter(Mandatory=$false)]
    [string]$MavenVersion = "3.9.5",
    
    [Parameter(Mandatory=$false)]
    [string]$QuarkusVersion = "3.15.1"
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Quarkus Development Environment Setup" -ForegroundColor Cyan
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

# Function to check if a command exists
function Test-Command {
    param($CommandName)
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $command -ne $null
}

# Install Chocolatey if not present
Write-Host "Checking Chocolatey installation..." -ForegroundColor Yellow
if (-not (Test-Command "choco")) {
    Write-Host "[INFO] Installing Chocolatey package manager..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        if (Test-CommandSuccess $LASTEXITCODE "Failed to install Chocolatey") {
            Write-Host "[SUCCESS] Chocolatey installed successfully" -ForegroundColor Green
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
    }
    catch {
        Write-Host "[ERROR] Failed to install Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[SUCCESS] Chocolatey is already installed" -ForegroundColor Green
}

# Check Java installation
Write-Host "Checking Java installation..." -ForegroundColor Yellow
$javaInstalled = $false
try {
    $javaVersion = java -version 2>&1
    if ($LASTEXITCODE -eq 0 -and $javaVersion -match "17\.|11\.") {
        Write-Host "[SUCCESS] Java is already installed: $($javaVersion[0])" -ForegroundColor Green
        $javaInstalled = $true
    }
}
catch {
    Write-Host "[INFO] Java not found or incompatible version" -ForegroundColor Yellow
}

if (-not $javaInstalled) {
    Write-Host "[INFO] Installing OpenJDK $JavaVersion..." -ForegroundColor Cyan
    choco install openjdk$JavaVersion -y
    if (Test-CommandSuccess $LASTEXITCODE "Failed to install Java") {
        Write-Host "[SUCCESS] Java $JavaVersion installed successfully" -ForegroundColor Green
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
}

# Check Maven installation
Write-Host "Checking Maven installation..." -ForegroundColor Yellow
if (-not (Test-Command "mvn")) {
    Write-Host "[INFO] Installing Maven $MavenVersion..." -ForegroundColor Cyan
    choco install maven -y
    if (Test-CommandSuccess $LASTEXITCODE "Failed to install Maven") {
        Write-Host "[SUCCESS] Maven installed successfully" -ForegroundColor Green
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
} else {
    $mavenVersion = mvn -version 2>$null | Select-String "Apache Maven" | Select-Object -First 1
    Write-Host "[SUCCESS] Maven is already installed: $mavenVersion" -ForegroundColor Green
}

# Check Git installation
Write-Host "Checking Git installation..." -ForegroundColor Yellow
if (-not (Test-Command "git")) {
    Write-Host "[INFO] Installing Git..." -ForegroundColor Cyan
    choco install git -y
    if (Test-CommandSuccess $LASTEXITCODE "Failed to install Git") {
        Write-Host "[SUCCESS] Git installed successfully" -ForegroundColor Green
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
} else {
    $gitVersion = git --version 2>$null
    Write-Host "[SUCCESS] Git is already installed: $gitVersion" -ForegroundColor Green
}

# Install Quarkus CLI
Write-Host "Installing Quarkus CLI..." -ForegroundColor Yellow
if (-not (Test-Command "quarkus")) {
    Write-Host "[INFO] Installing Quarkus CLI..." -ForegroundColor Cyan
    choco install quarkus -y
    if (Test-CommandSuccess $LASTEXITCODE "Failed to install Quarkus CLI") {
        Write-Host "[SUCCESS] Quarkus CLI installed successfully" -ForegroundColor Green
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
} else {
    try {
        $quarkusVersion = quarkus version 2>$null
        Write-Host "[SUCCESS] Quarkus CLI is already installed: $quarkusVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "[SUCCESS] Quarkus CLI is already installed" -ForegroundColor Green
    }
}

# Verify installations
Write-Host "`n===========================================" -ForegroundColor Yellow
Write-Host "Verifying Development Environment" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow

Write-Host "Java version:" -ForegroundColor Cyan
try { java -version } catch { Write-Host "[ERROR] Java verification failed" -ForegroundColor Red }

Write-Host "`nMaven version:" -ForegroundColor Cyan
try { mvn -version } catch { Write-Host "[ERROR] Maven verification failed" -ForegroundColor Red }

Write-Host "`nGit version:" -ForegroundColor Cyan
try { git --version } catch { Write-Host "[ERROR] Git verification failed" -ForegroundColor Red }

Write-Host "`nQuarkus CLI version:" -ForegroundColor Cyan
try { quarkus version } catch { Write-Host "[ERROR] Quarkus CLI verification failed" -ForegroundColor Red }

# Create a sample Quarkus project
Write-Host "`n===========================================" -ForegroundColor Yellow
Write-Host "Creating Sample Quarkus Project" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow

$projectDir = ".\sample-quarkus-app"
if (Test-Path $projectDir) {
    Write-Host "[INFO] Removing existing sample project..." -ForegroundColor Yellow
    Remove-Item $projectDir -Recurse -Force
}

Write-Host "[INFO] Creating new Quarkus project..." -ForegroundColor Cyan
quarkus create app sample-quarkus-app `
    --group-id=com.example `
    --artifact-id=sample-quarkus-app `
    --version=1.0.0-SNAPSHOT `
    --java-version=$JavaVersion `
    --extension=resteasy-reactive,resteasy-reactive-jackson,smallrye-health,micrometer-registry-prometheus

if (Test-CommandSuccess $LASTEXITCODE "Failed to create Quarkus project") {
    Write-Host "[SUCCESS] Sample Quarkus project created successfully" -ForegroundColor Green
    
    # Show project structure
    Write-Host "`nProject structure:" -ForegroundColor Cyan
    tree $projectDir /F /A 2>$null
    if ($LASTEXITCODE -ne 0) {
        Get-ChildItem $projectDir -Recurse | Select-Object FullName
    }
}

Write-Host "`n===========================================" -ForegroundColor Green
Write-Host "Quarkus Setup Completed Successfully!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

Write-Host "Development Environment:" -ForegroundColor Cyan
Write-Host "  Java: OpenJDK $JavaVersion" -ForegroundColor White
Write-Host "  Maven: $MavenVersion" -ForegroundColor White
Write-Host "  Quarkus CLI: Latest" -ForegroundColor White
Write-Host "  Git: Latest" -ForegroundColor White

Write-Host "`nSample Project Created:" -ForegroundColor Cyan
Write-Host "  Location: .\sample-quarkus-app" -ForegroundColor White
Write-Host "  Group ID: com.example" -ForegroundColor White
Write-Host "  Artifact ID: sample-quarkus-app" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. cd sample-quarkus-app" -ForegroundColor White
Write-Host "2. quarkus dev  # Start development mode with hot reload" -ForegroundColor White
Write-Host "3. Open http://localhost:8080 in your browser" -ForegroundColor White
Write-Host "4. Deploy Camel K: .\scripts\03-install-camelk.ps1" -ForegroundColor White

Write-Host "`nUseful Commands:" -ForegroundColor Cyan
Write-Host "  quarkus build                    # Build the application" -ForegroundColor White
Write-Host "  quarkus build --native           # Build native executable" -ForegroundColor White
Write-Host "  docker build -t my-app .         # Build container image" -ForegroundColor White
Write-Host "  kubectl apply -f kubernetes/     # Deploy to Kubernetes" -ForegroundColor White