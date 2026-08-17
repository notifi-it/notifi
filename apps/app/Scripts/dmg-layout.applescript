on run argv
	set volumeName to item 1 of argv

	tell application "Finder"
		tell disk volumeName
			open

			set current view of container window to icon view
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			set the bounds of container window to {200, 120, 860, 530}

			set opts to the icon view options of container window
			set arrangement of opts to not arranged
			set icon size of opts to 128
			set label position of opts to bottom
			set text size of opts to 12
			set background picture of opts to file ".background:background.png"

			set position of item "notifi.app" to {170, 214}
			set position of item "Applications" to {490, 214}

			close
			open
			update without registering applications
			delay 2
			close
		end tell
	end tell
end run
