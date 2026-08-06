-- circle_spec.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- Drives the circle's OnUpdate and checks the segment count it actually draws, and that
-- an out-of-range saved value gets clamped on load rather than reaching BuildCircleLines
-- unchanged -- a regression test for #6 (unbounded segments can hang the client).

return function(stub, T)
    print("circle:")

    T.Test("OnUpdate shows exactly circleSegments textures", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")
        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")

        local circleFrame = addon.ns.circleFrame
        circleFrame._scripts.OnUpdate(circleFrame, 1.0) -- elapsed well past the 30ms throttle

        local visible = 0
        for _, tex in ipairs(circleFrame._children) do
            if tex.kind == "Texture" and tex._shown then visible = visible + 1 end
        end
        T.AssertEqual(visible, addon.env.CrosshairsDB.circleSegments)
    end)

    T.Test("a steady-state tick re-anchors nothing (#10)", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")
        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")

        local circleFrame = addon.ns.circleFrame
        circleFrame._scripts.OnUpdate(circleFrame, 1.0) -- first tick: radius is new, must anchor

        local firstSegment = circleFrame._children[1]
        local callsAfterFirstTick = firstSegment._setPointCalls

        circleFrame._scripts.OnUpdate(circleFrame, 1.0) -- same radius: should not re-anchor

        T.AssertEqual(firstSegment._setPointCalls, callsAfterFirstTick,
            "SetPoint was called again on an unchanged-radius tick")
    end)

    T.Test("a hostile saved segment count is clamped on load", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        addon.env.CrosshairsDB = { circleSegments = 999999 }
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")

        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")

        T.AssertEqual(addon.env.CrosshairsDB.circleSegments, addon.ns.limits.circleSegments.max)
    end)
end
