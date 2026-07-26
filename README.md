Crosshairs Addon
=================

World of Warcraft retail addon (compatible with 12.0) that draws a cross at the center of the screen and a configurable cursor circle.

Installation
------------
Copy the folder to your World of Warcraft installation:

- Windows: World of Warcraft\_retail_\Interface\AddOns\crosshairs

Usage
-----
- The center cross is visible based on your settings (in/out of combat).
- A light-blue circle is drawn around the cursor. Hold the Alt key to expand the circle.

Options Panel
-------------
Open the Game Menu (Esc) > Options > AddOns > Crosshairs to configure everything with checkboxes and sliders instead of slash commands: visibility in/out of combat for the cross and circle, cross size/thickness, circle radius/segments/line thickness, debug mode, and a "Reset to Defaults" button. `/crosshairs options` (or `/ch options`) opens this panel directly.

Commands
--------
- `/crosshairs status` - show current settings
- `/crosshairs set <cross|circle> <in|out> <on|off>` - enable/disable the cross or circle while in or out of combat
  - Example: `/crosshairs set circle in on` (enable circle while in combat)
- `/crosshairs set segments <n>` - set circle segment count (more => smoother)
- `/crosshairs set thickness <n>` - set segment thickness (px)
- `/crosshairs set radius <n>` - set base radius (px)
- `/crosshairs set crosssize <n>` - set cross leg length (px)
- `/crosshairs set crossthickness <n>` - set cross thickness (px)
- `/crosshairs off` - hide both the cross and circle until re-enabled
- `/crosshairs on` - restore visibility based on current settings
- `/crosshairs circletest` - show test circle at screen center
- `/crosshairs test` - segment test circle
- `/crosshairs diag` - diagnostic overlay (lines + dots)
- `/crosshairs debug on|off` - show/hide cursor debug dot (enables detailed logs)
- `/crosshairs options` - open the graphical options panel and show command help (alias: `/ch`)

Notes
-----
### Version 1.0
- Cross: two 100-pixel lines intersecting at screen center, 2 pixels thick, red.
- Circle: light blue, composed of small segments; base radius ~40px and expands while Alt is pressed.
- Settings are saved between sessions (SavedVariables: `CrosshairsDB`).

### Version 1.1
- Circle now brightens clockwise from the top based on cast or global cooldown progress.
- Increased brightness range for better visibility.
- Added `/crosshairs off` and `/crosshairs on` commands for global visibility control.
- Fixed errors related to API availability and texture handling.
- Updated TOC to 12.0.5.

### Version 1.1.1
- Fixed addon load issue when the options panel is unavailable during Blizzard settings registration.
- Added safety checks around `InterfaceOptions_AddCategory` / `Settings.RegisterAddOnCategory` calls.
- Improved debug logging for settings registration failures.

### Version 1.1.2
- Updated TOC Interface to 12.0.7 (Interface: 120007).

### Version 1.2.0
**Feature summary:** a full graphical options panel, reachable the same way as other addons (e.g. AutoMailer), so settings no longer require slash commands.
- Added an options panel under Game Menu (Esc) > Options > AddOns > Crosshairs:
  - Checkboxes for cross/circle visibility in and out of combat, and debug mode.
  - Sliders for cross size/thickness and circle base radius/segment count/line thickness.
  - A "Reset to Defaults" button that restores every setting at once.
- `/crosshairs options` (and `/ch options`) now opens the panel directly, in addition to printing the slash command list.
- Fixed a bug where the options panel/category and the `circletest` toggle state were never properly declared as locals, so the panel could never actually register and the toggle leaked into globals.
- Removed dead code left over from an earlier preview feature (`UpdatePreview` calls that referenced a function which no longer existed).
- Added a `.luacheckrc` and cleaned up the addon so it lints clean with `luacheck`.

### Version 1.2.1
- Licensed under GPLv3.
- The addon version now prints to chat on login and is shown in the top-right corner of the options panel.

License
-------
This addon is licensed under the GNU General Public License v3.0 (GPLv3). See [LICENSE](LICENSE) for the full text.

