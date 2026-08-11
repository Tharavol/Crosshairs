-- Slash.lua
-- SPDX-License-Identifier: GPL-3.0
-- Slash command handling: /crosshairs (alias /ch)

local _, ns = ...

-- "8-256" for a setting, so the usage text and the clamp message can never quote a
-- range the code doesn't actually enforce.
local function Range(key)
    local limit = ns.limits[key]
    return limit.min .. "-" .. limit.max
end

-- Every "set <command> <n>" setting in one table -- DB key, display label (matches the
-- options panel's slider label), usage text, and the apply callback to run after a
-- change. Adding a setting means adding one entry here; the setter, status output and
-- PrintUsage are all derived from it, so they can't drift out of sync with each other.
local NUMERIC_SETTINGS = {
    {
        command = "segments", key = "circleSegments",
        label = "Segments", statusLabel = "circle segments",
        description = "circle segment count", note = "(more => smoother)",
        apply = function() ns.BuildCircleLines() end,
    },
    {
        command = "thickness", key = "circleLineThickness",
        label = "Line thickness", statusLabel = "circle thickness",
        description = "segment thickness in px",
        apply = function() ns.BuildCircleLines() end,
    },
    {
        command = "radius", key = "circleBaseRadius",
        label = "Base radius", statusLabel = "circle base radius",
        description = "base radius in px",
        -- No rebuild: the radius is read straight from the DB by the circle's OnUpdate.
        apply = nil,
    },
    {
        command = "crosssize", key = "crossSize",
        label = "Cross size", statusLabel = "cross size",
        description = "cross leg length in px",
        apply = function() ns.ApplyCrossSettings() end,
    },
    {
        command = "crossthickness", key = "crossThickness",
        label = "Cross thickness", statusLabel = "cross thickness",
        description = "cross thickness in px",
        apply = function() ns.ApplyCrossSettings() end,
    },
}

local NUMERIC_SETTINGS_BY_COMMAND = {}
for _, entry in ipairs(NUMERIC_SETTINGS) do
    NUMERIC_SETTINGS_BY_COMMAND[entry.command] = entry
end

-- "set <cross|circle> <in|out> <on|off>": a category/when pair addresses one boolean.
local VISIBILITY_SETTINGS = {
    { category = "cross", when = "in", key = "crossInCombat", statusLabel = "cross in combat" },
    { category = "cross", when = "out", key = "crossOutOfCombat", statusLabel = "cross out of combat" },
    { category = "circle", when = "in", key = "circleInCombat", statusLabel = "circle in combat" },
    { category = "circle", when = "out", key = "circleOutOfCombat", statusLabel = "circle out of combat" },
}

local VISIBILITY_SETTINGS_BY_COMMAND = {}
for _, entry in ipairs(VISIBILITY_SETTINGS) do
    VISIBILITY_SETTINGS_BY_COMMAND[entry.category] = VISIBILITY_SETTINGS_BY_COMMAND[entry.category] or {}
    VISIBILITY_SETTINGS_BY_COMMAND[entry.category][entry.when] = entry
end

-- The options panel only pulls fresh values from CrosshairsDB when it's shown (see
-- Options.lua's OnShow), so a slash command run while the panel is already open left it
-- displaying stale checkboxes/sliders until closed and reopened. Every setter below that
-- touches a value the panel also displays calls this afterward to keep the two in sync.
local function RefreshOptionsPanel()
    if ns.optionsPanel and ns.optionsPanel.RefreshWidgets then
        ns.optionsPanel.RefreshWidgets()
    end
end

-- Applies a clamped numeric setting and says so when the value was adjusted, since
-- silently storing something other than what was typed reads as the command failing.
local function SetNumeric(entry, input)
    local value, clamped = ns.ClampSetting(entry.key, input)
    CrosshairsDB[entry.key] = value
    if entry.apply then entry.apply() end
    RefreshOptionsPanel()
    if clamped then
        ns.Print(entry.label .. " set to " .. value .. " (clamped to " .. Range(entry.key) .. ")")
    else
        ns.Print(entry.label .. " set to " .. value)
    end
end

local function PrintStatus()
    ns.Print("force off:", tostring(CrosshairsDB.forceOff))
    for _, entry in ipairs(VISIBILITY_SETTINGS) do
        ns.Print(entry.statusLabel .. ":", tostring(CrosshairsDB[entry.key]))
    end
    for _, entry in ipairs(NUMERIC_SETTINGS) do
        ns.Print(entry.statusLabel .. ":", tostring(CrosshairsDB[entry.key]))
    end
end

local function OpenOptionsPanel()
    if Settings and Settings.OpenToCategory and ns.optionsCategoryID then
        -- Blizzard's API sometimes needs to be called twice to focus correctly on first open
        Settings.OpenToCategory(ns.optionsCategoryID)
        Settings.OpenToCategory(ns.optionsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory and ns.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
    end
end

-- Built once at load, and reused two ways: as the "set" command's own help lines
-- below, and as the scoped usage printed when "set" is given too few arguments to
-- resolve (e.g. "/ch set segments" with no value) -- distinct from the generic
-- "unknown command" case (S4), since "set" itself was a recognised word.
local SET_HELP = {
    "/crosshairs set <cross|circle> <in|out> <on|off> - set visibility in/out of combat " ..
        "(also accepts true|false)",
}
for _, entry in ipairs(NUMERIC_SETTINGS) do
    local note = entry.note and (" " .. entry.note) or ""
    SET_HELP[#SET_HELP + 1] = "/crosshairs set " .. entry.command .. " <n> - set " .. entry.description ..
        ", " .. Range(entry.key) .. note
end

local function HandleSet(args)
    local what = args[2] and args[2]:lower()

    -- Checked before the visibility family below (which used to come first and,
    -- because it only required three more words, swallowed any numeric setter
    -- invoked with a trailing word -- e.g. "set segments 200 please" reported
    -- "unknown setting: segments" instead of applying it.
    local numeric = NUMERIC_SETTINGS_BY_COMMAND[what]
    if numeric and tonumber(args[3]) then
        SetNumeric(numeric, args[3])
        return
    end

    if args[3] and args[4] then
        local when = args[3]:lower()
        local value = args[4]:lower()
        local whenTable = VISIBILITY_SETTINGS_BY_COMMAND[what]
        if whenTable then
            local visibility = whenTable[when]
            if not visibility then
                ns.Print("unknown option: " .. args[3])
                return
            end
            -- `when` was already validated above; `value` wasn't, so any typo (e.g.
            -- "onn") silently evaluated to false and reported success as if it had
            -- worked (#52). Reject anything but on/off/true/false instead.
            local enabled
            if value == "on" or value == "true" then
                enabled = true
            elseif value == "off" or value == "false" then
                enabled = false
            else
                ns.Print("unknown value: " .. args[4] .. " (expected on|off)")
                return
            end
            CrosshairsDB[visibility.key] = enabled
            ns.ApplyCombatState()
            RefreshOptionsPanel()
            ns.Print("Setting applied.")
            return
        end
        ns.Print("unknown setting: " .. tostring(what))
        return
    end

    ns.Print("Usage:")
    for _, line in ipairs(SET_HELP) do
        ns.Print(line)
    end
end

local function HandleDebug(args)
    local value = args[2] and args[2]:lower()
    local enabled
    if value == "on" then
        enabled = true
    elseif value == "off" then
        enabled = false
    elseif not value then
        -- Bare `debug` toggles and reports the new state (S8), same as an explicit
        -- on/off rather than a blind flip nobody can predict the result of.
        enabled = not CrosshairsDB.debugMode
    else
        ns.Print("unknown value: " .. args[2] .. " (expected on|off)")
        return
    end
    ns.SetDebugMode(enabled)
    RefreshOptionsPanel()
    ns.Print("debug mode set to", enabled and "on" or "off")
end

-- Table of { name, help, handler }, so PrintUsage is derived from the same data
-- Dispatch matches against instead of a second hand-maintained list that could
-- drift out of sync (S13; matches ShoppingConverter/Commands.lua's COMMANDS).
-- "", "config" and "gui" are silent aliases of "options" (S5): each opens the
-- panel but carries no help text of its own, so usage doesn't repeat the same
-- line four times.
local COMMANDS = {
    {name = "", help = {}, handler = OpenOptionsPanel},
    {
        name = "options",
        help = {
            "/crosshairs, /crosshairs options, /crosshairs config, /crosshairs gui - " ..
                "open the graphical options panel",
        },
        handler = OpenOptionsPanel,
    },
    {name = "config", help = {}, handler = OpenOptionsPanel},
    {name = "gui", help = {}, handler = OpenOptionsPanel},
    {name = "status", help = {"/crosshairs status - show current settings"}, handler = PrintStatus},
    {
        name = "version",
        help = {"/crosshairs version - show the addon version"},
        handler = function() ns.Print(ns.GetAddonVersion()) end,
    },
    {
        name = "reset",
        help = {"/crosshairs reset - restore settings to defaults"},
        handler = ns.ResetToDefaults,
    },
    {
        name = "off",
        help = {"/crosshairs off - hide both the cross and circle until re-enabled"},
        handler = function()
            CrosshairsDB.forceOff = true
            ns.ApplyCombatState()
            ns.Print("all crosshair elements turned off")
        end,
    },
    {
        name = "on",
        help = {"/crosshairs on - restore visibility based on current settings"},
        handler = function()
            CrosshairsDB.forceOff = nil
            ns.ApplyCombatState()
            ns.Print("crosshair visibility restored")
        end,
    },
    {
        name = "debug",
        help = {"/crosshairs debug [on|off] - toggle or set cursor debug dot and diagnostic messages"},
        handler = HandleDebug,
    },
    {name = "set", help = SET_HELP, handler = HandleSet},
}

local function PrintUsage()
    ns.Print("commands (alias: /ch):")
    for _, entry in ipairs(COMMANDS) do
        for _, line in ipairs(entry.help) do
            ns.Print(line)
        end
    end
end

COMMANDS[#COMMANDS + 1] = {name = "help", help = {"/crosshairs help - show this list"}, handler = PrintUsage}

SLASH_CROSSHAIRS1 = "/crosshairs"
SLASH_CROSSHAIRS2 = "/ch"
SlashCmdList["CROSSHAIRS"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do table.insert(args, word) end

    -- Only the command word is lowercased for matching (S11); "set"'s own
    -- sub-tokens are lowercased individually inside HandleSet, since a blanket
    -- lower() on the whole message is the pattern that corrupts the first
    -- case-sensitive argument this addon ever grows.
    local cmd = args[1] and args[1]:lower() or ""

    for _, entry in ipairs(COMMANDS) do
        if entry.name == cmd then
            entry.handler(args)
            return
        end
    end

    -- A typo must be visibly a typo, never a silent fallback (S4).
    ns.Print("unknown command: " .. cmd)
    PrintUsage()
end
