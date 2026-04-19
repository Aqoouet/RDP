# RDP tunnel diagnostics (run on Windows WORK PC)
# Usage (PowerShell):  cd <folder> ; .\work-pc-rdp-diagnostics.ps1
# If blocked:  powershell -ExecutionPolicy Bypass -File .\work-pc-rdp-diagnostics.ps1
#
# Paste the FULL output when asking for help.

$ErrorActionPreference = 'Continue'

# --- Edit if your VPS or port changed ---
$VpsIp   = '141.105.70.66'
$RdpPort = 23389
$SshPort = 22

function Section { param([string]$Title) Write-Host "`n======== $Title ========" -ForegroundColor Cyan }

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

Section "TCP to VPS - RDP tunnel port $RdpPort (required for mstsc)"
try {
  $tnc = Test-NetConnection -ComputerName $VpsIp -Port $RdpPort -WarningAction Continue
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

Section 'Done'
Write-Host "Send everything above (from Environment through Done) as plain text."
Write-Host "In mstsc use:      ${VpsIp}:${RdpPort}"
