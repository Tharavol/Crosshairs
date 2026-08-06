Crosshairs Addon
=================

World of Warcraft retail addon (compatible with 12.0) that draws a cross at the center of the screen and a configurable cursor circle.

Installation
------------
Copy the folder to your World of Warcraft installation:

- Windows: World of Warcraft\_retail_\Interface\AddOns\Crosshairs

Usage
-----
- The center cross is visible based on your settings (in/out of combat).
- A circle is drawn around the cursor and brightens clockwise to track cast and global cooldown progress. Hold the Alt key to expand it.

Options Panel
-------------
Open the Game Menu (Esc) > Options > AddOns > Crosshairs to configure everything with checkboxes, sliders and colour swatches instead of slash commands: visibility in/out of combat for the cross and circle, cross size/thickness, circle radius/segments/line thickness, cross and circle colour, debug mode, and a "Reset to Defaults" button. `/crosshairs options` (or `/ch options`) opens this panel directly.

Commands
--------
- `/crosshairs status` - show current settings
- `/crosshairs set <cross|circle> <in|out> <on|off>` - enable/disable the cross or circle while in or out of combat
  - Example: `/crosshairs set circle in on` (enable circle while in combat)
- `/crosshairs set segments <n>` - set circle segment count, 8-256 (more => smoother)
- `/crosshairs set thickness <n>` - set segment thickness in px, 1-20
- `/crosshairs set radius <n>` - set base radius in px, 4-150
- `/crosshairs set crosssize <n>` - set cross leg length in px, 4-200
- `/crosshairs set crossthickness <n>` - set cross thickness in px, 1-30

Numeric values are clamped to the ranges above and rounded to whole numbers, matching the options sliders; the command tells you when it adjusts a value.
- `/crosshairs off` - hide both the cross and circle until re-enabled
- `/crosshairs on` - restore visibility based on current settings
- `/crosshairs debug on|off` - show/hide cursor debug dot (enables detailed logs)
- `/crosshairs options` - open the graphical options panel and show command help (alias: `/ch`)

Release notes are in [CHANGELOG.md](CHANGELOG.md).

Development
-----------
- `luacheck .` lints the addon.
- `lua scripts/validate-toc.lua` runs the same TOC check CI does, from the repository root.
- `lua tests/run_tests.lua` runs the addon against a stubbed WoW API, from the repository root.

License
-------
This addon is licensed under the GNU General Public License v3.0 (GPLv3). See [LICENSE](LICENSE) for the full text.

