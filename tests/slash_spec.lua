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
end
