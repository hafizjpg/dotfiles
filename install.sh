#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
SDDM_THEME_NAME="silent"

c_green() { echo -e "\033[0;32m$*\033[0m"; }
c_red()   { echo -e "\033[0;31m$*\033[0m"; }
c_blue()  { echo -e "\033[0;34m$*\033[0m"; }

# ---------- 0. sanity checks ----------
if ! command -v pacman &>/dev/null; then
    c_red "This installer is Arch-only (needs pacman)."
    exit 1
fi

# ---------- 1. AUR helper ----------
if ! command -v yay &>/dev/null; then
    c_blue "Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm base-devel git
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# ---------- 2. packages from committed lists ----------
if [ -f "$DOTS_DIR/pacman-pkgs.txt" ]; then
    c_blue "Installing pacman packages..."
    sudo pacman -S --needed --noconfirm - < "$DOTS_DIR/pacman-pkgs.txt"
else
    c_red "pacman-pkgs.txt not found, skipping official repo packages"
fi

if [ -f "$DOTS_DIR/aur-pkgs.txt" ]; then
    c_blue "Installing AUR packages..."
    yay -S --needed --noconfirm - < "$DOTS_DIR/aur-pkgs.txt"
else
    c_red "aur-pkgs.txt not found, skipping AUR packages"
fi

# ---------- 3. enable services ----------
c_blue "Enabling services..."
sudo systemctl enable NetworkManager.service 2>/dev/null || true
sudo systemctl enable bluetooth.service 2>/dev/null || true
sudo systemctl enable sddm.service

# ---------- 4. symlink configs ----------
c_blue "Linking configs to ~/.config ..."
mkdir -p "$CONFIG_DIR"
for dir in "$DOTS_DIR"/config/*/; do
    name=$(basename "$dir")
    target="$CONFIG_DIR/$name"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mv "$target" "$target.bak.$(date +%s)"
        c_red "  backed up existing $target"
    fi
    ln -sfn "$dir" "$target"
    echo "  linked $name"
done

# symlink loose files directly under config/ (e.g. starship.toml)
for file in "$DOTS_DIR"/config/*.toml; do
    [ -e "$file" ] || continue
    name=$(basename "$file")
    target="$CONFIG_DIR/$name"
    [ -e "$target" ] && [ ! -L "$target" ] && mv "$target" "$target.bak.$(date +%s)"
    ln -sfn "$file" "$target"
    echo "  linked $name"
done

# ---------- 5. wallpapers ----------
c_blue "Installing wallpapers..."
mkdir -p "$WALLPAPER_DIR"
cp -n "$DOTS_DIR"/wallpapers/* "$WALLPAPER_DIR/" 2>/dev/null || true

# ---------- 6. SDDM theme ----------
if [ -d "$DOTS_DIR/sddm-theme/$SDDM_THEME_NAME" ]; then
    c_blue "Installing SDDM theme..."
    sudo cp -r "$DOTS_DIR/sddm-theme/$SDDM_THEME_NAME" "/usr/share/sddm/themes/$SDDM_THEME_NAME"

    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=$SDDM_THEME_NAME
EOF
    c_green "SDDM theme '$SDDM_THEME_NAME' installed and set active."
else
    c_red "No SDDM theme found at sddm-theme/$SDDM_THEME_NAME, skipping."
fi

# ---------- 7. default shell ----------
if command -v fish &>/dev/null && [ "$SHELL" != "$(command -v fish)" ]; then
    c_blue "Setting fish as default shell..."
    chsh -s "$(command -v fish)" || c_red "Failed to chsh, do it manually: chsh -s $(command -v fish)"
fi

c_green "Done. Reboot and select Hyprland at the SDDM login screen."
