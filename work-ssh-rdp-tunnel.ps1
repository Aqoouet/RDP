# SSH tunnel: work PC -> VPS -> home xrdp (use when ONLY port 22 works from office).
# Keeps a window open; then mstsc to 127.0.0.1 and the LocalPort below.
#
# One-time on Windows: copy PRIVATE key from home PC:
#   Linux:  ~/.ssh/id_ed25519_work_tunnel
#   Windows:  %USERPROFILE%\.ssh\id_ed25519_work_tunnel   (create .ssh folder if needed)
# Set permissions: right-click key -> Properties -> Security -> only your user.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\work-ssh-rdp-tunnel.ps1
#   .\work-ssh-rdp-tunnel.ps1 -LocalPort 13389
#
# Then:  mstsc  ->  Computer:  127.0.0.1:13389
# xrdp login: your Linux user on the HOME machine (e.g. aqouet), not root.

[CmdletBinding()]
param(
  [string]$VpsHost = '141.105.70.66',
  [string]$SshUser = 'root',
  [string]$IdentityFile = "$env:USERPROFILE\.ssh\id_ed25519_work_tunnel",
  [int]$LocalPort = 13389,
  [string]$HomeWgIp = '10.8.0.2',
  [int]$HomeRdpPort = 3389
)

$ssh = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh.exe'
if (-not (Test-Path -LiteralPath $ssh)) {
  Write-Host "OpenSSH client not found at $ssh. Install 'OpenSSH Client' (Windows optional feature)." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path -LiteralPath $IdentityFile)) {
  Write-Host "Missing key file: $IdentityFile" -ForegroundColor Red
  Write-Host "Copy id_ed25519_work_tunnel from your home PC to that path (private key - never email or commit)." -ForegroundColor Yellow
  exit 1
}

$remote = "${HomeWgIp}:${HomeRdpPort}"
Write-Host ""
Write-Host "Starting SSH tunnel (leave this window open)." -ForegroundColor Cyan
Write-Host "  Local:  127.0.0.1:${LocalPort}  ->  VPS ->  ${remote} (home PC over WireGuard)" -ForegroundColor Cyan
Write-Host "  Next:   mstsc  ->  127.0.0.1:${LocalPort}" -ForegroundColor Green
Write-Host ""

& $ssh -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 `
  -i $IdentityFile `
  -L "${LocalPort}:${remote}" `
  "${SshUser}@${VpsHost}"
