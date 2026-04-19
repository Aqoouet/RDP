# RDP: work PC → home PC (via VPS)

Your **home PC is this Linux machine** (Arch). The VPS forwards **`141.105.70.66:23389` → `10.8.0.2:3389`** on the tunnel.

## On the home PC (this PC) — before / while you need access

1. **WireGuard**
   - Master copy: **`/home/aqouet/Desktop/RDP/home-pc.conf`** (no `DNS =` line — avoids **resolvconf** issues on Arch).
   - **Boot / auto:** same config is installed as **`/etc/wireguard/rdp-home.conf`** and **`wg-quick@rdp-home.service`** is **enabled** — the tunnel comes up after reboot.
   - Manual: `sudo wg-quick up /home/aqouet/Desktop/RDP/home-pc.conf` (only if the service is stopped; do not run two clients with the same keys at once).
   - Check: `ping -c 2 10.8.0.1` (should reply while the tunnel is up).
   - Stop (if you disabled the service): `sudo systemctl stop wg-quick@rdp-home` or `sudo wg-quick down /etc/wireguard/rdp-home.conf`
2. **RDP server on Linux** (for **mstsc** / RDP clients)
   - **xrdp** + **xorgxrdp** are installed from the **AUR** (not in official repos). **`xrdp`** and **`xrdp-sesman`** are **enabled** and listen on **TCP 3389**.
   - **Plasma (X11):** **`~/.xinitrc`** runs **`startplasma-x11`** so xrdp gets a full KDE session. Log in with your **Linux username** (e.g. `aqouet`) and **your user password**.
   - If you use a host firewall, allow **3389/tcp** (traffic arrives via the tunnel to this host).

## On the work PC

1. Open **Remote Desktop Connection** (`Win + R` → `mstsc`).
2. **Computer:** `141.105.70.66:23389`
3. Sign in with your **Linux / xrdp** credentials (not a Windows account).

If the work PC is also Linux, use an RDP client (e.g. **Remmina**, **freerdp**) pointing at `141.105.70.66:23389` the same way.

## If it does not connect

- Home: WireGuard must stay **up** (`ping 10.8.0.1` works).
- Home: **xrdp** (or your RDP server) must be **running** and listening on **3389**.
- Home: not sleeping / not suspending if you need it reachable.
- Office: some networks block odd TCP ports; if needed, change the **public** port on the VPS (e.g. to **443**) and update firewalld there.

## SSH to the VPS (optional)

From this PC: `ssh vps-rdp` (see `~/.ssh/config`).
