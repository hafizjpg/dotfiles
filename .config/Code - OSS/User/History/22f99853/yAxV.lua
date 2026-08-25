-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
	hl.exec_cmd("qs & awww-daemon & hypridle")
hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")   
	--   hl.exec_cmd("nm-applet")
	--   hl.exec_cmd("waybar & hyprpaper & firefox")
end)

