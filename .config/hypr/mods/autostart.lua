-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("qs & awww-daemon & hypridle")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'") 
end)

