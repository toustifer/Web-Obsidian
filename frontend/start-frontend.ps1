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
