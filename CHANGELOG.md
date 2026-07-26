# Changelog

All notable changes to the Crosshairs addon are documented in this file.

## [1.2.1]
- Licensed under GPLv3 (see LICENSE).
- The addon now prints its version at login and shows it in the top-right corner of the options panel.

## [1.2.0]
**Feature summary:** a full graphical options panel, reachable the same way as other addons (e.g. AutoMailer), so settings no longer require slash commands.
- Added an options panel under Game Menu (Esc) > Options > AddOns > Crosshairs:
  - Checkboxes for cross/circle visibility in and out of combat, and debug mode.
  - Sliders for cross size/thickness and circle base radius/segment count/line thickness.
  - A "Reset to Defaults" button that restores every setting at once.
- `/crosshairs options` (and `/ch options`) now opens the panel directly, in addition to printing the slash command list.
- Fixed a bug where the options panel/category and the `circletest` toggle state were never properly declared as locals, so the panel could never actually register and the toggle leaked into globals.
- Removed dead code left over from an earlier preview feature (`UpdatePreview` calls that referenced a function which no longer existed).
- Added a `.luacheckrc` and cleaned up the addon so it lints clean with `luacheck`.

## [1.1.2]
- Updated TOC Interface to 12.0.7 (Interface: 120007).

## [1.1.1]
- Fixed addon load issue when the options panel is unavailable during Blizzard settings registration.
- Added safety checks around `InterfaceOptions_AddCategory` / `Settings.RegisterAddOnCategory` calls.
- Improved debug logging for settings registration failures.

## [1.1]
- Circle now brightens clockwise from the top based on cast or global cooldown progress.
- Increased brightness range for better visibility.
- Added `/crosshairs off` and `/crosshairs on` commands for global visibility control.
- Fixed errors related to API availability and texture handling.
- Updated TOC to 12.0.5.

## [1.0]
- Cross: two 100-pixel lines intersecting at screen center, 2 pixels thick, red.
- Circle: light blue, composed of small segments; base radius ~40px and expands while Alt is pressed.
- Settings are saved between sessions (SavedVariables: `CrosshairsDB`).
