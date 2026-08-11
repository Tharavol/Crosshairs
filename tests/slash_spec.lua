-- slash_spec.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- Drives the /crosshairs slash handler with hostile input and checks it clamps rather
-- than storing (or hanging on) an out-of-range value.

return function(stub, T)
    print("slash:")

    local function LoggedInAddon()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")
        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")
        return addon
    end

    T.Test("set segments above the max clamps instead of hanging the client", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("set segments 999999")
        T.AssertEqual(addon.env.CrosshairsDB.circleSegments, addon.ns.limits.circleSegments.max)
    end)

    T.Test("set radius below the min clamps up to it", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("set radius 0")
        T.AssertEqual(addon.env.CrosshairsDB.circleBaseRadius, addon.ns.limits.circleBaseRadius.min)
    end)

    T.Test("set with a non-numeric value leaves the stored setting untouched", function()
        local addon = LoggedInAddon()
        local before = addon.env.CrosshairsDB.circleSegments
        addon.env.SlashCmdList["CROSSHAIRS"]("set segments banana")
        T.AssertEqual(addon.env.CrosshairsDB.circleSegments, before)
    end)

    T.Test("a trailing word after a numeric setter still applies the value (#8)", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("set segments 200 please")
        T.AssertEqual(addon.env.CrosshairsDB.circleSegments, 200)
    end)

    T.Test("set cross in on toggles the visibility setting", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("set cross in on")
        T.AssertEqual(addon.env.CrosshairsDB.crossInCombat, true)
    end)

    T.Test("set cross in true also toggles the visibility setting", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("set cross in true")
        T.AssertEqual(addon.env.CrosshairsDB.crossInCombat, true)
    end)

    T.Test("a garbled visibility value is rejected instead of silently applied as off (#52)", function()
        local addon = LoggedInAddon()
        local before = addon.env.CrosshairsDB.crossInCombat
        addon.env.SlashCmdList["CROSSHAIRS"]("set cross in onn")
        T.AssertEqual(addon.env.CrosshairsDB.crossInCombat, before)
    end)

    -- The options panel only re-reads CrosshairsDB when it's shown (Options.lua's OnShow),
    -- so a slash command run while the panel is already open used to leave its checkboxes
    -- and sliders showing stale values until the panel was closed and reopened. Each setter
    -- family now calls RefreshWidgets itself; these confirm that wiring stays in place.
    local function CountRefreshes(addon)
        local calls = 0
        local original = addon.ns.optionsPanel.RefreshWidgets
        addon.ns.optionsPanel.RefreshWidgets = function(...)
            calls = calls + 1
            return original(...)
        end
        return function() return calls end
    end

    T.Test("a visibility slash command refreshes an already-open options panel", function()
        local addon = LoggedInAddon()
        local Calls = CountRefreshes(addon)
        addon.env.SlashCmdList["CROSSHAIRS"]("set cross in off")
        T.AssertEqual(Calls(), 1)
    end)

    T.Test("a numeric slash command refreshes an already-open options panel", function()
        local addon = LoggedInAddon()
        local Calls = CountRefreshes(addon)
        addon.env.SlashCmdList["CROSSHAIRS"]("set segments 100")
        T.AssertEqual(Calls(), 1)
    end)

    T.Test("a debug slash command refreshes an already-open options panel", function()
        local addon = LoggedInAddon()
        local Calls = CountRefreshes(addon)
        addon.env.SlashCmdList["CROSSHAIRS"]("debug on")
        T.AssertEqual(Calls(), 1)
    end)

    -- Cross-addon slash command standard (#57): S2 bare opens the panel, S3 help is
    -- a real command, S4 unknown input says so, S7 version, S8 debug bare-toggles,
    -- S9 reset from the command line.

    local function CountPanelOpens(addon)
        local calls = 0
        local original = addon.env.Settings.OpenToCategory
        addon.env.Settings.OpenToCategory = function(...)
            calls = calls + 1
            return original(...)
        end
        return function() return calls end
    end

    T.Test("an empty command opens the options panel (S2), not usage", function()
        local addon = LoggedInAddon()
        local Calls = CountPanelOpens(addon)
        addon.env.SlashCmdList["CROSSHAIRS"]("")
        -- OpenToCategory is deliberately called twice per open (see OpenOptionsPanel).
        T.AssertEqual(Calls(), 2)
    end)

    T.Test("options no longer dumps the full command list after opening the panel", function()
        local addon = LoggedInAddon()
        local before = #addon.api.chatLog
        addon.env.SlashCmdList["CROSSHAIRS"]("options")
        T.AssertEqual(#addon.api.chatLog, before)
    end)

    T.Test("config and gui are silent aliases that also open the panel", function()
        local addon = LoggedInAddon()
        local Calls = CountPanelOpens(addon)
        addon.env.SlashCmdList["CROSSHAIRS"]("config")
        addon.env.SlashCmdList["CROSSHAIRS"]("gui")
        T.AssertEqual(Calls(), 4)
    end)

    T.Test("help prints the full command list", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("help")
        local found = false
        for _, line in ipairs(addon.api.chatLog) do
            if line:find("open the graphical options panel", 1, true) then found = true end
        end
        T.AssertEqual(found, true)
    end)

    T.Test("an unknown command names what was unrecognised (S4)", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("bogus")
        T.AssertEqual(addon.api.chatLog[1]:find("unknown command: bogus", 1, true) ~= nil, true)
    end)

    T.Test("version prints the addon version", function()
        local addon = LoggedInAddon()
        addon.env.SlashCmdList["CROSSHAIRS"]("version")
        T.AssertEqual(addon.api.chatLog[1]:find("v", 1, true) ~= nil, true)
    end)

    T.Test("bare debug toggles the current state and reports it", function()
        local addon = LoggedInAddon()
        addon.env.CrosshairsDB.debugMode = false
        addon.env.SlashCmdList["CROSSHAIRS"]("debug")
        T.AssertEqual(addon.env.CrosshairsDB.debugMode, true)
        addon.env.SlashCmdList["CROSSHAIRS"]("debug")
        T.AssertEqual(addon.env.CrosshairsDB.debugMode, false)
    end)

    T.Test("an invalid debug value is rejected instead of silently applied (S12)", function()
        local addon = LoggedInAddon()
        addon.env.CrosshairsDB.debugMode = true
        addon.env.SlashCmdList["CROSSHAIRS"]("debug maybe")
        T.AssertEqual(addon.env.CrosshairsDB.debugMode, true)
    end)

    T.Test("reset restores settings to defaults", function()
        local addon = LoggedInAddon()
        addon.env.CrosshairsDB.circleSegments = 250
        addon.env.SlashCmdList["CROSSHAIRS"]("reset")
        T.AssertEqual(addon.env.CrosshairsDB.circleSegments, addon.ns.defaults.circleSegments)
    end)
end
