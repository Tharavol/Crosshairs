# Changelog

All notable changes to the Crosshairs addon are documented in this file.

## [1.4.0]

Appearance and docs. The one group of changes since 1.2.4 that changes what existing
users actually see.

- Fixed the "Base radius" slider drawing 0.7x the value it displayed — a hidden scale factor meant a slider labelled "40" actually drew a 28px circle. Folded the factor into the default and deleted it; the slider now means what it says. Anyone with a saved non-default radius sees a one-time increase to match (accepted rather than migrated — not worth a SavedVariables version bump for a cosmetic value).
- Added colour swatches to the options panel for cross and circle colour (`ColorPickerFrame`-backed, stored as `{r,g,b,a}`), and raised the cross to the circle's strata (`MEDIUM`) so ordinary UI — action bars, a centred nameplate — can no longer occlude it entirely. Dark red over a dark dungeon floor was close to invisible before this.
- Fixed the options panel's widgets drifting up to 40px right down the page — each slider anchored 8px right of whatever it followed, and the offset compounded through the chain. Indentation is now measured from the panel's content column instead of the previous widget.
- Modernised the options panel's checkbox and slider templates (`UICheckButtonTemplate`, `UISliderTemplateWithLabels`), verified against several currently-maintained addons' actual field usage rather than guessed. Falls back to the previous templates if a modern one fails to resolve on a given client, so a bad guess degrades instead of breaking the panel.
- Trimmed the README's Notes section (a duplicate, less-complete copy of this changelog) down to a link here.



Structural work. No intended change in user-facing behaviour, except the circle's
per-tick rendering path (#10), which changes how the circle is drawn but not what it
looks like.

- Fixed slash dispatch reporting `unknown setting: segments` for `/ch set segments <n>` followed by a trailing word (e.g. `/ch set segments 200 please`) — the generic 4-argument visibility-toggle branch was checked before the numeric setters and swallowed them. Dispatch is now table-driven: each numeric setting is one entry (DB key, label, apply callback), matched before visibility toggles regardless of trailing words.
- Cut the circle's per-tick WoW API calls from roughly 20,000/sec at the default 200 segments to a handful. Segment geometry (`SetPoint`) is now cached and only recomputed when radius or segment count actually changes; colour is set once at build time and only alpha (`SetAlpha`) varies per tick. Cursor tracking now runs every frame instead of sharing the segment-appearance throttle, so the circle no longer visibly trails the cursor.
- Added `ns.Print`, giving every chat output site — previously each retyping `Crosshairs: `, and `status` with no prefix at all — one consistent, coloured, greppable prefix.
- Added a stub-API test harness (`tests/`), run in CI, that loads the addon against a stubbed WoW API and checks version-string formatting, `ADDON_LOADED` defaults, combat-visibility combinations, clamped hostile input, and the segment re-anchoring behaviour above.
- Removed load-time `pcall` calls in `Cross.lua`/`Circle.lua` that claimed to apply saved settings before `PLAYER_LOGIN` but, since SavedVariables aren't populated until `ADDON_LOADED`, only ever applied defaults. Defaults are now filled in exactly once, at `ADDON_LOADED`.

## [1.2.4]

Correctness fixes. No restructuring and no intended change to how anything looks.

- Fixed the cursor circle never tracking the global cooldown. `GetGCDFraction` used the pre-11.0 `GetSpellCooldown` signature, but modern retail returns a single info table, so the function returned `nil` on every call — silently, with no Lua error. The circle brightened only during an actual cast. It now branches on `C_Spell.GetSpellCooldown` and falls back to the old tuple form.
- Fixed debug mode being lost on `/reload`. The debug dot's `OnUpdate` polled the setting to show or hide itself, but WoW doesn't run `OnUpdate` on hidden frames, so it could never un-hide itself; it only ever appeared because the toggles called `Show()` directly. The script is now attached and cleared on toggle, and the saved state is applied at `PLAYER_LOGIN`.
- Fixed slash setters accepting unbounded values. `/ch set segments 100000` created 100,000 textures and hung the client, and because the value was saved it hung again on the next login. Ranges now live in one table in `Core.lua` that both the sliders and the slash setters read; the setters clamp, round to whole numbers, and report when they adjust a value. Settings already saved out of range are pulled back in on load, so an affected profile repairs itself.
- Fixed the login message reading `Crosshairs vv1.2.3 loaded` — release tags already carry a leading `v`, and both display sites prepended a second one. An unsubstituted `@project-version@`, which is what a git clone sees, now reports as `dev`.
- Fixed `## Title` displaying as lowercase `crosshairs` in the in-game AddOns list, and reworded `## Notes`, which described only the crosshair and not the cursor circle.
- Fixed the README documenting the lowercase `AddOns\crosshairs` install path — the exact mismatch v1.2.3 existed to correct.
- Removed `CF_API_KEY` from the release workflow. It required an `## X-Curse-Project-ID` that was never added, so the path it documented could not work.
- Added a CI check that validates the TOC: every listed file exists with matching case, `## Interface` is a well-formed 5- or 6-digit number, `## Version` is present, and the TOC basename matches `package-as` in `.pkgmeta`.

## [1.2.3]

Packaging and tooling only — no functional changes.

- Renamed `crosshairs.toc` to `Crosshairs.toc` so it matches the addon folder name. WoW resolves this case-insensitively on Windows and macOS, but the packager and case-sensitive filesystems do not, so the mismatch was a latent packaging failure.
- Releases are now built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager), so the zip contains only what the addon needs — `.github/`, `.luacheckrc` and `.pkgmeta` no longer ship.
- The version in the TOC now comes from the release tag instead of being maintained by hand, so it can no longer disagree with the release it was published under. Versions now carry a leading `v`.
- Added a GitHub Actions workflow running luacheck on every push and pull request.

## [1.2.2]
- Split the addon into `Core.lua`, `Cross.lua`, `Circle.lua`, `Options.lua`, and `Slash.lua` (previously one 700+ line file), sharing state through an addon-namespace table instead of file-scope locals.
- Removed the dev-only `/crosshairs test`, `diag`, and `circletest` commands and their scaffolding (test frames, forced-visibility hacks) — they were left over from building the circle renderer and had no use for end users.
- Removed per-tick debug spam (cursor position and quadrant-sample prints firing ~33 times/second) that made debug mode unusable; debug mode now logs only on actual setting changes.
- Fixed the circle segment size being computed by two different, disagreeing formulas in `BuildCircleLines` and `updateCirclePositions`; both now share one `GetSegmentSize` helper.
- Lowered the "Segments" slider max from 720 to 256 and the default from 512 to 200 — each segment is its own texture redrawn every ~30ms, so the old max risked real frame cost for little visible smoothness gain.
- Named the magic spell ID used for GCD tracking (`GCD_SPELL_ID = 61304`) with an explanatory comment.
- Added SPDX license headers to all source files.

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
