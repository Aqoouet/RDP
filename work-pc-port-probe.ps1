# Probe which TCP ports from WORK PC to VPS are reachable (outbound firewall hint).
# Does NOT mean the VPS serves RDP on that port - you must configure firewalld DNAT to match.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\work-pc-port-probe.ps1
# Optional:
#   powershell -ExecutionPolicy Bypass -File .\work-pc-port-probe.ps1 -VpsIp 141.105.70.66 -TimeoutMs 3000

param(
  [string]$VpsIp = '141.105.70.66',
  [int]$TimeoutMs = 2500
)

$ErrorActionPreference = 'Stop'

# Ports often allowed on corporate networks; edit this list if you like.
$PortsToTry = @(
  22,    # SSH (you already know this works)
  80,    # HTTP
  443,   # HTTPS
  8080,  # alt HTTP
  8443,  # alt HTTPS
  3389,  # RDP (sometimes blocked outbound)
  23389, # your current tunnel port
  2222,  # alt SSH
  5900,  # VNC
  8000,
  8888,
  9443,
  5000,
  1935,
  53     # TCP DNS (unusual for connect test)
)

function Test-TcpConnect {
  param(
    [string]$TargetHost,
    [int]$Port,
    [int]$Timeout
  )
  $tcp = $null
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect($TargetHost, $Port, $null, $null)
    if (-not $iar.AsyncWaitHandle.WaitOne($Timeout, $false)) {
      return 'timeout'
    }
    $tcp.EndConnect($iar)
    return 'open'
  } catch {
    return 'fail'
  } finally {
    if ($null -ne $tcp) {
      try { $tcp.Close() } catch { }
    }
  }
}

Write-Host ""
Write-Host "VPS: $VpsIp  Timeout: ${TimeoutMs}ms per port" -ForegroundColor Cyan
Write-Host "open    = TCP handshake succeeded (something accepted the connection)" -ForegroundColor Green
Write-Host "fail    = refused / error (nothing listening or RST)" -ForegroundColor Yellow
Write-Host "timeout = no response (often blocked by firewall / drop)" -ForegroundColor Red
Write-Host ""

$rows = foreach ($p in ($PortsToTry | Select-Object -Unique | Sort-Object)) {
  $r = Test-TcpConnect -TargetHost $VpsIp -Port $p -Timeout $TimeoutMs
  [PSCustomObject]@{ Port = $p; Result = $r }
}

$rows | Format-Table -AutoSize

$open = @($rows | Where-Object { $_.Result -eq 'open' } | ForEach-Object { $_.Port })
Write-Host "Ports that reached the VPS (TCP open): $($open -join ', ')" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: pick one OPEN port, set VPS firewalld forward-port to that port -> 10.8.0.2:3389,"
Write-Host "or use SSH -L if only 22 is open. Copy this output when asking for help."
Write-Host ""
