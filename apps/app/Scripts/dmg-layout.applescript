-- Lays out the mounted disk image: window size, icon positions, background.
--
-- Run against a *read-write* image. Finder writes this into the volume's
-- .DS_Store, and a compressed UDZO image is read-only, so a layout applied
-- after conversion is discarded without an error.
--
-- The coordinates below are the ones generate-dmg-background.sh prints. They
-- are duplicated rather than read from the asset because the asset is a PNG;
-- if either moves, both move.
on run argv
	set volumeName to item 1 of argv

	tell application "Finder"
		tell disk volumeName
			open

			set current view of container window to icon view
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			-- {left, top, right, bottom} in screen coordinates. The size is what
			-- matters; the origin only decides where the window first appears.
			set the bounds of container window to {200, 120, 860, 530}

			set opts to the icon view options of container window
			set arrangement of opts to not arranged
			set icon size of opts to 128
			-- Labels sit under the icons, which is what the background's lower
			-- half is left clear for. To the side, they would run into the trail.
			set label position of opts to bottom
			set text size of opts to 12
			set background picture of opts to file ".background:background.png"

			set position of item "notifi.app" to {170, 214}
			set position of item "Applications" to {490, 214}

			-- Finder only flushes .DS_Store when it decides to. Closing and
			-- reopening is what makes it do so before the image is converted.
			close
			open
			update without registering applications
			delay 2
			-- Left open, Finder keeps the volume busy and the detach in the
			-- Fastfile fails with "Resource busy" after the layout succeeded.
			close
		end tell
	end tell
end run
