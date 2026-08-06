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

-- Applies a clamped numeric setting and says so when the value was adjusted, since
-- silently storing something other than what was typed reads as the command failing.
local function SetNumeric(key, input, onChange)
    local value, clamped = ns.ClampSetting(key, input)
    CrosshairsDB[key] = value
    if onChange then onChange() end
    if clamped then
        print("Crosshairs: " .. key .. " set to " .. value .. " (clamped to " .. Range(key) .. ")")
    else
        print("Crosshairs: " .. key .. " set to " .. value)
    end
end

local function PrintUsage()
    print("Crosshairs commands (alias: /ch):")
    print("/crosshairs options - open the graphical options panel")
    print("/crosshairs status - show current settings")
    print("/crosshairs set <cross|circle> <in|out> <on|off> - set visibility in/out of combat")
    print("/crosshairs set segments <n> - set circle segment count, " .. Range("circleSegments") ..
        " (more => smoother)")
    print("/crosshairs set thickness <n> - set segment thickness in px, " .. Range("circleLineThickness"))
    print("/crosshairs set radius <n> - set base radius in px, " .. Range("circleBaseRadius"))
    print("/crosshairs set crosssize <n> - set cross leg length in px, " .. Range("crossSize"))
    print("/crosshairs set crossthickness <n> - set cross thickness in px, " .. Range("crossThickness"))
    print("/crosshairs off - hide both the cross and circle until re-enabled")
    print("/crosshairs on - restore visibility based on current settings")
    print("/crosshairs debug on|off - show/hide cursor debug dot and diagnostic messages")
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
        print("force off:", tostring(CrosshairsDB.forceOff))
        print("cross in combat:", tostring(CrosshairsDB.crossInCombat))
        print("cross out of combat:", tostring(CrosshairsDB.crossOutOfCombat))
        print("circle in combat:", tostring(CrosshairsDB.circleInCombat))
        print("circle out of combat:", tostring(CrosshairsDB.circleOutOfCombat))
        print("circle segments:", tostring(CrosshairsDB.circleSegments))
        print("circle thickness:", tostring(CrosshairsDB.circleLineThickness))
        print("circle base radius:", tostring(CrosshairsDB.circleBaseRadius))
        print("cross size:", tostring(CrosshairsDB.crossSize))
        print("cross thickness:", tostring(CrosshairsDB.crossThickness))
        return
    end

    if args[1] == "off" then
        CrosshairsDB.forceOff = true
        ns.ApplyCombatState()
        print("Crosshairs: all crosshair elements turned off")
        return
    end

    if args[1] == "on" then
        CrosshairsDB.forceOff = nil
        ns.ApplyCombatState()
        print("Crosshairs: crosshair visibility restored")
        return
    end

    if args[1] == "debug" and (args[2] == "on" or args[2] == "off") then
        ns.SetDebugMode(args[2] == "on")
        print("Crosshairs: debug mode set to", args[2])
        return
    end

    if args[1] == "set" and args[2] and args[3] and args[4] then
        local what, when, val = args[2], args[3], args[4]
        local bool = (val == "on" or val == "true")
        if what == "cross" then
            if when == "in" then CrosshairsDB.crossInCombat = bool
            elseif when == "out" then CrosshairsDB.crossOutOfCombat = bool
            else print("unknown option: " .. when); return end
        elseif what == "circle" then
            if when == "in" then CrosshairsDB.circleInCombat = bool
            elseif when == "out" then CrosshairsDB.circleOutOfCombat = bool
            else print("unknown option: " .. when); return end
        else
            print("unknown setting: " .. what)
            return
        end
        ns.ApplyCombatState()
        print("Setting applied.")
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
