param(
    [string]$EnvFile = ".env"
)

function Prompt-Value {
    param(
        [string]$Label,
        [string]$Default = "",
        [switch]$Secret
    )
    $prompt = if ($Default) { "$Label [$Default]" } else { $Label }
    if ($Secret) {
        $value = Read-Host -Prompt $prompt -AsSecureString
        if ($value.Length -eq 0 -and $Default) { return $Default }
        return [Runtime.InteropServices.Marshal]::PtrToStringUni(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
        )
    } else {
        $value = Read-Host -Prompt $prompt
        if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
        return $value
    }
}

$workingDir = (Resolve-Path ".").Path
$defaultAppDir = $workingDir -replace "\\", "/"
$defaultProject = Split-Path $workingDir -Leaf
$defaultProject = ($defaultProject -replace "[^a-zA-Z0-9_-]", "").ToLower()
if (-not $defaultProject) { $defaultProject = "obsidian" }

Write-Host "=== Obsidian .env 配置向导 (PowerShell) ===" -ForegroundColor Cyan
$appDir = Prompt-Value -Label "APP_DIR (绝对路径, 推荐使用正斜杠)" -Default $defaultAppDir
$customUser = Prompt-Value -Label "CUSTOM_USER" -Default "admin"
$password = Prompt-Value -Label "PASSWORD" -Secret
if (-not $password) { $password = "password123" }
$projectName = Prompt-Value -Label "COMPOSE_PROJECT_NAME" -Default $defaultProject

$tailscaleIpDefault = ""
try {
    $tailscaleIpDefault = (tailscale ip -4 2>$null).Trim()
} catch {
    $tailscaleIpDefault = ""
}
$tailscaleIp = Prompt-Value -Label "TAILSCALE_IP (可先运行 'tailscale ip -4')" -Default $tailscaleIpDefault

$content = @(
    "APP_DIR=$appDir",
    "CUSTOM_USER=$customUser",
    "PASSWORD=$password",
    "COMPOSE_PROJECT_NAME=$projectName",
    "TAILSCALE_IP=$tailscaleIp"
) -join [Environment]::NewLine

Set-Content -Path $EnvFile -Value $content -Encoding UTF8
Write-Host "`n已写入 $EnvFile：" -ForegroundColor Green
Get-Content -Path $EnvFile
