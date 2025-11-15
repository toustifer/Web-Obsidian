param(
    [switch]$Install
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $ScriptDir

# 尝试将控制台设置为 UTF-8，确保 Electron/Node 的中文日志不出现乱码
try {
    chcp 65001 > $null
} catch {}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = New-Object System.Text.UTF8Encoding
$env:LANG = 'zh_CN.UTF-8'

Write-Host "Starting frontend from: $ScriptDir" -ForegroundColor Cyan

# Load environment variables from .env if present (simple KEY=VALUE parser)
$envFiles = @("$ScriptDir/.env","$ScriptDir/../.env")
foreach ($f in $envFiles) {
    if (Test-Path $f) {
        Write-Host "Loading env from $f"
        Get-Content $f | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                $parts = $line -split '=',2
                if ($parts.Count -eq 2) {
                    $key = $parts[0].Trim()
                    $value = $parts[1].Trim().Trim('"').Trim("'")
                    [System.Environment]::SetEnvironmentVariable($key,$value,'Process')
                }
            }
        }
        break
    }
}

# 本机可达性检测：优先使用本地地址（127.0.0.1）和正确端口
try {
    $localFound = $false
    # 先尝试 https://127.0.0.1:3001（跳过证书检查）
    try {
        $resp = Invoke-WebRequest -Uri 'https://127.0.0.1:3001/' -TimeoutSec 3 -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop
        if ($resp.StatusCode) {
            Write-Host "Detected local HTTPS service at 127.0.0.1:3001 (HTTP $($resp.StatusCode)). Using local address." -ForegroundColor Green
            [System.Environment]::SetEnvironmentVariable('TAILSCALE_IP','127.0.0.1','Process')
            [System.Environment]::SetEnvironmentVariable('FRONTEND_PORT','3001','Process')
            $localFound = $true
        }
    } catch {
        # 如果服务器返回了 4xx/5xx，Invoke-WebRequest 会抛出异常，但 Response 里可能包含 StatusCode
        try {
            $status = $_.Exception.Response.StatusCode.value__
        } catch {
            $status = $null
        }
        if ($status) {
            Write-Host "Detected local HTTPS service at 127.0.0.1:3001 (HTTP $status) via exception response. Using local address." -ForegroundColor Green
            [System.Environment]::SetEnvironmentVariable('TAILSCALE_IP','127.0.0.1','Process')
            [System.Environment]::SetEnvironmentVariable('FRONTEND_PORT','3001','Process')
            $localFound = $true
        }
    }

    if (-not $localFound) {
        try {
            $resp2 = Invoke-WebRequest -Uri 'http://127.0.0.1:3000/' -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            if ($resp2.StatusCode) {
                Write-Host "Detected local HTTP service at 127.0.0.1:3000 (HTTP $($resp2.StatusCode)). Using local address." -ForegroundColor Green
                [System.Environment]::SetEnvironmentVariable('TAILSCALE_IP','127.0.0.1','Process')
                [System.Environment]::SetEnvironmentVariable('FRONTEND_PORT','3000','Process')
                $localFound = $true
            }
        } catch {
            try {
                $status2 = $_.Exception.Response.StatusCode.value__
            } catch {
                $status2 = $null
            }
            if ($status2) {
                Write-Host "Detected local HTTP service at 127.0.0.1:3000 (HTTP $status2) via exception response. Using local address." -ForegroundColor Green
                [System.Environment]::SetEnvironmentVariable('TAILSCALE_IP','127.0.0.1','Process')
                [System.Environment]::SetEnvironmentVariable('FRONTEND_PORT','3000','Process')
                $localFound = $true
            }
        }
    }
    if (-not $localFound) {
        Write-Host "No local service detected on 127.0.0.1:3001/3000; will use configured TAILSCALE_IP." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Local probe failed: $_" -ForegroundColor Yellow
}

# If requested or node_modules missing, install dependencies
if ($Install -or -not (Test-Path (Join-Path $ScriptDir 'node_modules'))) {
    Write-Host "Installing npm dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "npm install failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Pop-Location
        exit $LASTEXITCODE
    }
}

Write-Host "Running npm start..." -ForegroundColor Green
npm start

$exitCode = $LASTEXITCODE
Pop-Location
exit $exitCode
