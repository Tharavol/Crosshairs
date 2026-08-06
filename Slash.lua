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

-- Display labels for chat output, matching the options panel's slider labels (Options.lua)
-- so a setting reads the same in the panel and in chat -- "Line thickness set to 4" rather
-- than the DB key "circleLineThickness set to 4".
local SETTING_LABELS = {
    circleSegments = "Segments",
    circleLineThickness = "Line thickness",
    circleBaseRadius = "Base radius",
    crossSize = "Cross size",
    crossThickness = "Cross thickness",
}

-- Applies a clamped numeric setting and says so when the value was adjusted, since
-- silently storing something other than what was typed reads as the command failing.
local function SetNumeric(key, input, onChange)
    local value, clamped = ns.ClampSetting(key, input)
    CrosshairsDB[key] = value
    if onChange then onChange() end
    local label = SETTING_LABELS[key] or key
    if clamped then
        ns.Print(label .. " set to " .. value .. " (clamped to " .. Range(key) .. ")")
    else
        ns.Print(label .. " set to " .. value)
    end
end

local function PrintUsage()
    ns.Print("commands (alias: /ch):")
    ns.Print("/crosshairs options - open the graphical options panel")
    ns.Print("/crosshairs status - show current settings")
    ns.Print("/crosshairs set <cross|circle> <in|out> <on|off> - set visibility in/out of combat")
    ns.Print("/crosshairs set segments <n> - set circle segment count, " .. Range("circleSegments") ..
        " (more => smoother)")
    ns.Print("/crosshairs set thickness <n> - set segment thickness in px, " .. Range("circleLineThickness"))
    ns.Print("/crosshairs set radius <n> - set base radius in px, " .. Range("circleBaseRadius"))
    ns.Print("/crosshairs set crosssize <n> - set cross leg length in px, " .. Range("crossSize"))
    ns.Print("/crosshairs set crossthickness <n> - set cross thickness in px, " .. Range("crossThickness"))
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

    if #args == 0 then
        PrintUsage()
        return
    end

    if args[1] == "options" or args[1] == "config" or args[1] == "gui" then
        OpenOptionsPanel()
        PrintUsage()
        return
    end

    if args[1] == "status" then
        ns.Print("force off:", tostring(CrosshairsDB.forceOff))
        ns.Print("cross in combat:", tostring(CrosshairsDB.crossInCombat))
        ns.Print("cross out of combat:", tostring(CrosshairsDB.crossOutOfCombat))
        ns.Print("circle in combat:", tostring(CrosshairsDB.circleInCombat))
        ns.Print("circle out of combat:", tostring(CrosshairsDB.circleOutOfCombat))
        ns.Print("circle segments:", tostring(CrosshairsDB.circleSegments))
        ns.Print("circle thickness:", tostring(CrosshairsDB.circleLineThickness))
        ns.Print("circle base radius:", tostring(CrosshairsDB.circleBaseRadius))
        ns.Print("cross size:", tostring(CrosshairsDB.crossSize))
        ns.Print("cross thickness:", tostring(CrosshairsDB.crossThickness))
        return
    end

    if args[1] == "off" then
        CrosshairsDB.forceOff = true
        ns.ApplyCombatState()
        ns.Print("all crosshair elements turned off")
        return
    end

    if args[1] == "on" then
        CrosshairsDB.forceOff = nil
        ns.ApplyCombatState()
        ns.Print("crosshair visibility restored")
        return
    end

    if args[1] == "debug" and (args[2] == "on" or args[2] == "off") then
        ns.SetDebugMode(args[2] == "on")
        ns.Print("debug mode set to", args[2])
        return
    end

    if args[1] == "set" and args[2] and args[3] and args[4] then
        local what, when, val = args[2], args[3], args[4]
        local bool = (val == "on" or val == "true")
        if what == "cross" then
            if when == "in" then CrosshairsDB.crossInCombat = bool
            elseif when == "out" then CrosshairsDB.crossOutOfCombat = bool
            else ns.Print("unknown option: " .. when); return end
        elseif what == "circle" then
            if when == "in" then CrosshairsDB.circleInCombat = bool
            elseif when == "out" then CrosshairsDB.circleOutOfCombat = bool
            else ns.Print("unknown option: " .. when); return end
        else
            ns.Print("unknown setting: " .. what)
            return
        end
        ns.ApplyCombatState()
        ns.Print("Setting applied.")
        return
    end

    if args[1] == "set" and args[2] == "segments" and tonumber(args[3]) then
        SetNumeric("circleSegments", args[3], ns.BuildCircleLines)
        return
    end

    if args[1] == "set" and args[2] == "thickness" and tonumber(args[3]) then
        SetNumeric("circleLineThickness", args[3], ns.BuildCircleLines)
        return
    end

    if args[1] == "set" and args[2] == "radius" and tonumber(args[3]) then
        -- No rebuild: the radius is read straight from the DB by the circle's OnUpdate.
        SetNumeric("circleBaseRadius", args[3])
        return
    end

    if args[1] == "set" and args[2] == "crosssize" and tonumber(args[3]) then
        SetNumeric("crossSize", args[3], ns.ApplyCrossSettings)
        return
    end

    if args[1] == "set" and args[2] == "crossthickness" and tonumber(args[3]) then
        SetNumeric("crossThickness", args[3], ns.ApplyCrossSettings)
        return
    end

    PrintUsage()
end
