param(
    [string]$EnvFile = ".env",
    [string]$ComposeFile = ".\docker-compose.yml"
)

function Load-EnvFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "Environment file '$Path' not found." -ForegroundColor Red
        exit 1
    }
    Get-Content $Path | ForEach-Object {
        if ($_ -match "^\s*($|#)") { return }
        if ($_ -match "^(?<Key>[^=]+)=(?<Value>.*)$") {
            $key = $matches.Key.Trim()
            $value = $matches.Value.Trim()
            ${env:$key} = $value
        }
    }
}

Load-EnvFile -Path $EnvFile

$projectName = $env:COMPOSE_PROJECT_NAME
if (-not $projectName) { $projectName = "obi" }
$localPorts = @("3000","3001","8082")
if ($env:LOCAL_PORTS) {
    $localPorts = $env:LOCAL_PORTS.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries)
}

Write-Host "Stopping docker compose..." -ForegroundColor Cyan
docker compose -f $ComposeFile -p $projectName down 2>$null

Write-Host "Resetting tailscale serve..." -ForegroundColor Cyan
tailscale serve reset
foreach ($port in $localPorts) {
    tailscale serve clear --tcp=$port 2>$null
}

Write-Host "Starting Docker Desktop (if needed)..." -ForegroundColor Cyan
$dockerDesktop = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerDesktop) {
    Start-Process -FilePath $dockerDesktop `
        -ArgumentList "--unattended" `
        -WindowStyle Hidden `
        -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
}

Write-Host "Bringing services up..." -ForegroundColor Cyan
if (docker ps -a --format '{{.Names}}' | Select-String -SimpleMatch 'obsidian') {
    Write-Host "Removing leftover obsidian container..." -ForegroundColor Yellow
    docker rm -f obsidian | Out-Null
}
docker compose -f $ComposeFile -p $projectName up -d

Write-Host "curl http://127.0.0.1:3000" -ForegroundColor Cyan
curl http://127.0.0.1:3000

Write-Host "Re-publishing ports via tailscale serve..." -ForegroundColor Cyan
foreach ($port in $localPorts) {
    tailscale serve --bg --tcp=$port "tcp://127.0.0.1:$port"
}

Write-Host "`nCurrent tailscale serve status:" -ForegroundColor Cyan
tailscale serve status

$targets = @(
    @{ Uri = "http://127.0.0.1:3000"; Label = "HTTP"; SkipCert = $false },
    @{ Uri = "https://127.0.0.1:3000"; Label = "HTTPS"; SkipCert = $true }
)
$maxAttempts = 15
$responded = $false

Write-Host "`nWaiting for 127.0.0.1:3000 to respond..." -ForegroundColor Cyan
for ($i = 1; $i -le $maxAttempts -and -not $responded; $i++) {
    foreach ($target in $targets) {
        try {
            $params = @{
                Uri = $target.Uri
                UseBasicParsing = $true
                TimeoutSec = 5
                ErrorAction = "Stop"
            }
            if ($target.SkipCert) {
                $params["SkipCertificateCheck"] = $true
            }
            $response = Invoke-WebRequest @params
            Write-Host "Port 3000 responded via $($target.Label) (HTTP $($response.StatusCode)) on attempt ${i}" -ForegroundColor Green
            $responded = $true
            break
        } catch {
            $statusCode = $_.Exception?.Response?.StatusCode?.value__
            if ($statusCode) {
                Write-Host "Port 3000 responded via $($target.Label) (HTTP $statusCode) on attempt ${i}" -ForegroundColor Green
                $responded = $true
                break
            } else {
                Write-Host "Attempt ${i} ($($target.Label)): still waiting..." -ForegroundColor Yellow
            }
        }
    }
    if (-not $responded) {
        Start-Sleep -Seconds 3
    }
}

if (-not $responded) {
    Write-Host "Port 3000 did not respond after $maxAttempts attempts." -ForegroundColor Red
}

if ($env:TAILSCALE_IP) {
    Write-Host "`nTailnet access: http://$($env:TAILSCALE_IP):3000" -ForegroundColor Cyan
}
