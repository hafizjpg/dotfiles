# hyprlarp

> larping as someone with their life together, one pixel at a time<img width="1366" height="768" alt="2026-07-19-170517_hyprshot" src="https://github.com/user-attachments/assets/950adc14-6723-4b4e-8e63-ac3b0fe3bd1a" />
<img width="1366" height="768" alt="2026-07-19-170511_hyprshot" src="https://github.com/user-attachments/assets/00edeff9-9d4c-4221-95ba-210f2fdc4127" />


![Made with Arch](https://img.shields.io/badge/Arch-BTW-1793D1?logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-6E50EB)
![Quickshell](https://img.shields.io/badge/Shell-Quickshell-6E50EB)
![License](https://img.shields.io/badge/license-MIT-gray)

---

## What's in here

- **Quickshell** — Dynamic Island pill that expands into a full status bar. Workspaces, MPRIS, quick settings, the works.
- **Hyprland** — Lua config, animation curves named like a JRPG spell list (`glass`, `snap`, `slingshot`, `silk`, `bounce`).
- **Hyprlock** — frosted glass card, ambient glow orbs, deep-space blur.
- **SDDM theme** — `silent`, set to boot into vibes.
- **Kitty + Fish + Rofi + Neovim + Starship + fastfetch + swaync + waypaper** — the rest of the terminal-native aesthetic.

Accent color: `#6E50EB`. Non-negotiable.

## Preview

*(drop a screenshot or two here — `hyprshot -m region` and toss it in `assets/`)*

## Install

One command, does everything:

```bash
git clone https://github.com/hafizjpg/dotfiles ~/hyprlarp
cd ~/hyprlarp
./install.sh
```

This will:
1. Install `yay` if missing
2. Install every package in `pacman-pkgs.txt` and `aur-pkgs.txt`
3. Enable NetworkManager, Bluetooth, SDDM
4. Symlink every config folder into `~/.config`, backing up anything already there
5. Drop wallpapers into `~/Pictures/wallpapers`
6. Install and activate the `silent` SDDM theme
7. Set fish as your default shell

Reboot. Pick Hyprland at the login screen. Done.

## Manual install

If you'd rather cherry-pick instead of running the full script:

```bash
# packages
sudo pacman -S --needed - < pacman-pkgs.txt
yay -S --needed - < aur-pkgs.txt

# configs (symlink whichever you want)
ln -sfn ~/hyprlarp/config/hypr ~/.config/hypr
ln -sfn ~/hyprlarp/config/quickshell ~/.config/quickshell
# ...etc

# sddm theme
sudo cp -r sddm-theme/silent /usr/share/sddm/themes/silent
echo -e "[Theme]\nCurrent=silent" | sudo tee /etc/sddm.conf.d/theme.conf
```

## Structure

```
hyprlarp/
├── install.sh              # the whole point
├── pacman-pkgs.txt
├── aur-pkgs.txt
├── config/
│   ├── hypr/
│   ├── hyprlock/
│   ├── quickshell/
│   ├── kitty/
│   ├── fish/
│   ├── rofi/
│   ├── nvim/
│   ├── fastfetch/
│   ├── swaync/
│   ├── waypaper/
│   └── starship.toml
├── sddm-theme/
│   └── silent/
└── wallpapers/
```

## Known issues

Adding more bugs to fix. Will fix soon (if I remember what the bug is).

## License

MIT — take it, break it, make it yours.
