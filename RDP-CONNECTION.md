# RDP: work PC → home PC (via VPS)

Your **home PC is this Linux machine** (Arch). The VPS has WireGuard to home **`10.8.0.2`** and can reach **xrdp** on **`10.8.0.2:3389`**.

## Path A - Direct RDP to VPS public port (when office allows it)

VPS **firewalld** forwards **`141.105.70.66:443` -> `10.8.0.2:3389`**.

1. **mstsc** -> **`141.105.70.66:443`**
2. xrdp: your **home Linux** user (e.g. `aqouet`), not root.

If **`work-pc-rdp-diagnostics.ps1`** shows **443 not reachable** but **22 OK**, use **Path B**.

## Path B - SSH tunnel (when ONLY port 22 works - strict office)

Traffic: **work PC -> SSH :22 -> VPS -> WG -> home :3389**.

### One-time setup

1. On **home PC**, the private key for work is **`~/.ssh/id_ed25519_work_tunnel`** (public key is already on the VPS for **root**).
2. Copy **only** the file **`id_ed25519_work_tunnel`** (no `.pub`) to the work PC:
   - **`%USERPROFILE%\.ssh\id_ed25519_work_tunnel`**
3. Do **not** put this key in Git, email, or chat.

### Every session on work PC

1. Home PC: **WireGuard** up, **xrdp** running (as usual).
2. Run **`work-ssh-rdp-tunnel.ps1`** (leave the window open):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\work-ssh-rdp-tunnel.ps1
   ```
3. **mstsc** -> **`127.0.0.1:13389`**
4. xrdp: your **home Linux** user and password.

## On the home PC (this PC) - before / while you need access

1. **WireGuard**
   - **`/home/aqouet/Desktop/RDP/home-pc.conf`** and **`/etc/wireguard/rdp-home.conf`** / **`wg-quick@rdp-home`**.
   - Check: **`ping -c 2 10.8.0.1`**
2. **xrdp** on **3389**. **`~/.xinitrc`** starts Plasma with **`dbus-run-session startplasma-x11`** and **software OpenGL** so KWin does not stall on a black screen over RDP.

### Black screen after the Plasma logo (xrdp)

- Already mitigated in **`~/.xinitrc`** (`LIBGL_ALWAYS_SOFTWARE=1`, `KWIN_OPENGL_INTERFACE=software`, `dbus-run-session`).
- After changing **`~/.xinitrc`**, disconnect RDP and on the home PC run: **`sudo systemctl restart xrdp xrdp-sesman`**, then connect again.
- If it persists: in an existing local Plasma session, **System Settings -> Display and Monitor -> Compositor** -> uncheck **Enable on startup**, or try session **Xorg** (not Wayland) in SDDM for comparison.
- Fallback desktop for RDP only: install **xfce4** and set **`~/.xinitrc`** to **`exec dbus-run-session startxfce4`** while debugging.

### Cursor / AppImage: "file not found" or two instances (local + RDP)

- **Cause:** Cursor is an **AppImage**; while it runs, `cursor` may point at **`/tmp/.mount_Cursor...`**, which **does not exist** in your xrdp session. Two **Plasma sessions** as **`aqouet`** (local + RDP) also confuse **Electron single-instance** (shared lock / IPC).
- **Fix on home PC:** use **`~/.local/bin/cursor-launch`** and the menu entry **Cursor (AppImage)** (`~/.local/share/applications/cursor-appimage.desktop`). On displays **:10+** (typical xrdp) it uses **`~/.config/Cursor-rdp`** so RDP does not fight the console Cursor.
- **Best practice:** **close Cursor** on the local session before RDP, or **log out locally** and use only RDP when working remotely.

## SSH to the VPS from home

- **`ssh vps-rdp`** (main key in **`~/.ssh/config`**).
- Work-tunnel key: **`ssh -i ~/.ssh/id_ed25519_work_tunnel root@141.105.70.66`** (for testing).
