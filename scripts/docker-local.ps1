#Requires -Version 5.1
param(
    [switch]$Prebuilt,

    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DocsRoot = Split-Path -Parent $ScriptDir
$CoreRoot = Split-Path -Parent $DocsRoot
$LocalDir = Join-Path $DocsRoot "local"
$ComposeFileName = if ($Prebuilt) { "docker-compose.prebuilt.yml" } else { "docker-compose.yml" }
$ComposeFile = Join-Path $LocalDir $ComposeFileName
$EnvFile = Join-Path $LocalDir ".env"
$EnvExample = Join-Path $LocalDir ".env.example"

$JarServices = @(
    @{ Name = "auth-service"; Path = "auth-service" },
    @{ Name = "user-management"; Path = "user-management" },
    @{ Name = "aitechtap-assist"; Path = "aitechtap-assist" },
    @{ Name = "plan-payment-service"; Path = "plan-payment-service" }
)

function Show-Usage {
    Write-Host "Usage: .\docker-local.ps1 [-Prebuilt] {build|up|down|logs|ps|jars} [extra args...]"
    Write-Host "  (no switch)        docker-compose.yml - Gradle runs inside Docker during image build"
    Write-Host "  -Prebuilt          docker-compose.prebuilt.yml - host gradlew bootJar, image copies JAR only"
    Write-Host ""
    Write-Host "  build              docker compose build (-Prebuilt: run bootJar on host first)"
    Write-Host "  up                 docker compose up -d (uses image built last; see README if stale)"
    Write-Host '  down               docker compose down (add --volumes to drop data)'
    Write-Host "  logs [service]     docker compose logs -f"
    Write-Host "  ps                 docker compose ps"
    if ($Prebuilt) {
        Write-Host "  jars               gradlew bootJar -x test in each service (extra args go to Gradle)"
    } else {
        Write-Host "  jars               only with -Prebuilt (host bootJar for all services)"
    }
}

function Invoke-JarsBuild {
    param([string[]]$GradleArgs = @())
    foreach ($svc in $JarServices) {
        $dir = Join-Path $CoreRoot $svc.Path
        if (-not (Test-Path $dir)) {
            Write-Error "Service directory not found: $dir"
            exit 1
        }
        $gradlew = Join-Path $dir "gradlew.bat"
        if (-not (Test-Path $gradlew)) {
            Write-Error "gradlew.bat not found: $gradlew"
            exit 1
        }
        Write-Host "=== bootJar: $($svc.Name) ==="
        Push-Location $dir
        try {
            & .\gradlew.bat bootJar --no-daemon -x test @GradleArgs
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        } finally {
            Pop-Location
        }
    }
}

if (-not (Test-Path $ComposeFile)) {
    Write-Error "Compose file not found: $ComposeFile"
    exit 1
}

if (-not (Test-Path $EnvFile)) {
    if (Test-Path $EnvExample) {
        Copy-Item $EnvExample $EnvFile
        Write-Host "Created $EnvFile from .env.example - review JWT_SECRET and passwords."
    } else {
        Write-Error "Missing $EnvFile and $EnvExample"
        exit 1
    }
}

if ($Prebuilt) {
    $env:DOCKER_BUILDKIT = "1"
    $env:COMPOSE_DOCKER_CLI_BUILD = "1"
}

Push-Location $LocalDir
try {
    $composeArgs = @("compose", "--env-file", ".env", "-f", $ComposeFileName)
    if ($Command -eq "build") {
        if ($Prebuilt) {
            Invoke-JarsBuild -GradleArgs @()
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        & docker @composeArgs @("build") @Rest
    } elseif ($Command -eq "up") {
        & docker @composeArgs @("up", "-d") @Rest
    } elseif ($Command -eq "down") {
        & docker @composeArgs @("down") @Rest
    } elseif ($Command -eq "logs") {
        & docker @composeArgs @("logs", "-f") @Rest
    } elseif ($Command -eq "ps") {
        & docker @composeArgs @("ps") @Rest
    } elseif ($Command -eq "jars") {
        if (-not $Prebuilt) {
            Write-Error "Command 'jars' requires -Prebuilt (host bootJar for all services)."
            Show-Usage
            exit 1
        }
        Invoke-JarsBuild -GradleArgs $Rest
    } elseif ($Command -eq "help" -or $Command -eq "-h" -or $Command -eq "--help") {
        Show-Usage
    } else {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
} finally {
    Pop-Location
}
