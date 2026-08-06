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

-- Applies a clamped numeric setting and says so when the value was adjusted, since
-- silently storing something other than what was typed reads as the command failing.
local function SetNumeric(entry, input)
    local value, clamped = ns.ClampSetting(entry.key, input)
    CrosshairsDB[entry.key] = value
    if entry.apply then entry.apply() end
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

local function PrintUsage()
    ns.Print("commands (alias: /ch):")
    ns.Print("/crosshairs options - open the graphical options panel")
    ns.Print("/crosshairs status - show current settings")
    ns.Print("/crosshairs set <cross|circle> <in|out> <on|off> - set visibility in/out of combat")
    for _, entry in ipairs(NUMERIC_SETTINGS) do
        local note = entry.note and (" " .. entry.note) or ""
        ns.Print("/crosshairs set " .. entry.command .. " <n> - set " .. entry.description .. ", " ..
            Range(entry.key) .. note)
    end
    ns.Print("/crosshairs off - hide both the cross and circle until re-enabled")
    ns.Print("/crosshairs on - restore visibility based on current settings")
    ns.Print("/crosshairs debug on|off - show/hide cursor debug dot and diagnostic messages")
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

SLASH_CROSSHAIRS1 = "/crosshairs"
SLASH_CROSSHAIRS2 = "/ch"
SlashCmdList["CROSSHAIRS"] = function(msg)
    msg = (msg or ""):lower()
    local args = {}
    for word in string.gmatch(msg, "%S+") do table.insert(args, word) end

    local cmd = args[1]

    if not cmd then
        PrintUsage()
        return
    end

    if cmd == "options" or cmd == "config" or cmd == "gui" then
        OpenOptionsPanel()
        PrintUsage()
        return
    end

    if cmd == "status" then
        PrintStatus()
        return
    end

    if cmd == "off" then
        CrosshairsDB.forceOff = true
        ns.ApplyCombatState()
        ns.Print("all crosshair elements turned off")
        return
    end

    if cmd == "on" then
        CrosshairsDB.forceOff = nil
        ns.ApplyCombatState()
        ns.Print("crosshair visibility restored")
        return
    end

    if cmd == "debug" and (args[2] == "on" or args[2] == "off") then
        ns.SetDebugMode(args[2] == "on")
        ns.Print("debug mode set to", args[2])
        return
    end

    if cmd == "set" then
        local what = args[2]

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
            local whenTable = VISIBILITY_SETTINGS_BY_COMMAND[what]
            if whenTable then
                local visibility = whenTable[args[3]]
                if not visibility then
                    ns.Print("unknown option: " .. args[3])
                    return
                end
                CrosshairsDB[visibility.key] = (args[4] == "on" or args[4] == "true")
                ns.ApplyCombatState()
                ns.Print("Setting applied.")
                return
            end
            ns.Print("unknown setting: " .. tostring(what))
            return
        end
    end

    PrintUsage()
end
