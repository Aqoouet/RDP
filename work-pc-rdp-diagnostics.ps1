# RDP tunnel diagnostics (Windows WORK PC). Safe to re-run anytime.
#
# Usage:
#   .\work-pc-rdp-diagnostics.ps1
#   powershell -ExecutionPolicy Bypass -File .\work-pc-rdp-diagnostics.ps1
#   .\work-pc-rdp-diagnostics.ps1 -VpsIp 141.105.70.66 -RdpPort 443
#   .\work-pc-rdp-diagnostics.ps1 -IncludePortProbe
#
# Paste the FULL output when asking for help.

[CmdletBinding()]
param(
  [string]$VpsIp = '141.105.70.66',
  [int]$RdpPort = 443,
  [int]$SshPort = 22,
  [int]$PortProbeTimeoutMs = 2500,
  [switch]$IncludePortProbe
)

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "RDP tunnel diagnostics - re-run after office/VPS/home PC changes." -ForegroundColor Cyan
Write-Host "Target: ${VpsIp}  RDP port: ${RdpPort}  SSH: ${SshPort}" -ForegroundColor Cyan
Write-Host ""

function Section { param([string]$Title) Write-Host "`n======== $Title ========" -ForegroundColor Cyan }

function Test-TcpQuick {
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

Section 'Environment'
Write-Host "When:              $(Get-Date -Format 'o')"
Write-Host "Computer:          $env:COMPUTERNAME"
Write-Host "User:              $env:USERNAME"
Write-Host "OS:                $([System.Environment]::OSVersion.VersionString)"
try {
  $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
  Write-Host "Display version:   $($os.Caption)"
} catch { Write-Host "Display version:   (could not read)" }

Section 'Network (summary)'
try {
  Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
    ForEach-Object {
      Write-Host "Interface:         $($_.InterfaceAlias)"
      Write-Host "IPv4 address:      $($_.IPv4Address.IPAddress)"
      Write-Host "Gateway:           $($_.IPv4DefaultGateway.NextHop)"
      Write-Host "DNS servers:       $(($_.DnsServer.ServerAddresses) -join ', ')"
    }
} catch {
  Write-Host "Get-NetIPConfiguration failed: $_"
}

Section "DNS resolve (VPS) $VpsIp"
try {
  $name = [System.Net.Dns]::GetHostEntry($VpsIp).HostName
  Write-Host "PTR / hostname:    $name"
} catch {
  Write-Host "Reverse lookup:    failed or none ($($_.Exception.Message))"
}

Section "ICMP ping (may be blocked - not required for RDP)"
try {
  $ping = Test-Connection -ComputerName $VpsIp -Count 2 -ErrorAction Stop
  $ping | ForEach-Object { Write-Host "Ping:              $($_.Address) $($_.ResponseTime) ms" }
} catch {
  Write-Host "Ping:              failed - $($_.Exception.Message)"
}

$script:RdpTcpOk = $false
$script:SshTcpOk = $false

Section "TCP to VPS - RDP tunnel port $RdpPort (required for mstsc)"
try {
  $tnc = Test-NetConnection -ComputerName $VpsIp -Port $RdpPort -WarningAction Continue
  $script:RdpTcpOk = [bool]$tnc.TcpTestSucceeded
  Write-Host "TcpTestSucceeded:  $($tnc.TcpTestSucceeded)"
  Write-Host "RemoteAddress:     $($tnc.RemoteAddress)"
  Write-Host "RemotePort:        $($tnc.RemotePort)"
  Write-Host "InterfaceAlias:    $($tnc.InterfaceAlias)"
  Write-Host "PingSucceeded:     $($tnc.PingSucceeded)"
} catch {
  Write-Host "Test-NetConnection failed: $_"
}

Section "TCP to VPS - SSH port $SshPort (optional - checks host reachable on another port)"
try {
  $tnc22 = Test-NetConnection -ComputerName $VpsIp -Port $SshPort -WarningAction Continue
  $script:SshTcpOk = [bool]$tnc22.TcpTestSucceeded
  Write-Host "TcpTestSucceeded:  $($tnc22.TcpTestSucceeded)"
} catch {
  Write-Host "Test-NetConnection: $_"
}

Section "TCP general HTTPS egress (optional - your PC can reach tcp/443 somewhere)"
try {
  $tnc443 = Test-NetConnection -ComputerName 'one.one.one.one' -Port 443 -WarningAction Continue
  Write-Host "TcpTestSucceeded:  $($tnc443.TcpTestSucceeded)  (to 1.1.1.1:443)"
} catch {
  Write-Host "Test-NetConnection: $_"
}

if ($IncludePortProbe) {
  Section "Extra port probe to VPS (TcpClient, ${PortProbeTimeoutMs}ms each)"
  $extraPorts = @(22, 80, 443, 8080, 8443, 3389, 23389, 2222)
  foreach ($p in ($extraPorts | Select-Object -Unique | Sort-Object)) {
    $r = Test-TcpQuick -TargetHost $VpsIp -Port $p -Timeout $PortProbeTimeoutMs
    Write-Host ("Port {0,-5} {1}" -f $p, $r)
  }
}

Section 'Proxy (can block corporate clients)'
try {
  $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
  $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
  $u = New-Object Uri("https://$VpsIp")
  $p = $proxy.GetProxy($u)
  Write-Host "System proxy URL:  $p"
} catch {
  Write-Host "Proxy check:       $_"
}

Section 'RDP process / MSTSC'
Get-Process mstsc -ErrorAction SilentlyContinue | Format-Table Id, ProcessName, StartTime -AutoSize
if (-not (Get-Command mstsc.exe -ErrorAction SilentlyContinue)) {
  Write-Host "mstsc.exe not in PATH (unusual on Windows client)"
} else {
  Write-Host "mstsc.exe:         $(Get-Command mstsc.exe | Select-Object -ExpandProperty Source)"
}

Section 'Summary'
if ($script:RdpTcpOk) {
  Write-Host "RDP port ${RdpPort}:  REACHABLE from this PC - try mstsc: ${VpsIp}:${RdpPort}" -ForegroundColor Green
} else {
  Write-Host "RDP port ${RdpPort}:  NOT reachable - office may block it, or VPS/home tunnel/xrdp is down." -ForegroundColor Red
}
if ($script:SshTcpOk) {
  Write-Host "SSH port ${SshPort}:  REACHABLE (optional fallback: ssh -L local:10.8.0.2:3389)." -ForegroundColor Green
} else {
  Write-Host "SSH port ${SshPort}:  not reachable from this PC." -ForegroundColor Yellow
}

Section 'Done'
Write-Host "Send everything above (from Environment through Done) as plain text."
Write-Host "Re-run:  powershell -ExecutionPolicy Bypass -File .\work-pc-rdp-diagnostics.ps1"
Write-Host "         .\work-pc-rdp-diagnostics.ps1 -IncludePortProbe"
