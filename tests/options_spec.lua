-- options_spec.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- Colour swatches and strata (#16): picking a colour updates the DB without corrupting
-- the shared defaults table, and the cross is raised to the circle's strata.

return function(stub, T)
    print("options:")

    T.Test("cross is raised to the circle's strata", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        T.AssertEqual(addon.ns.crossFrame._strata, addon.ns.circleFrame._strata)
    end)

    T.Test("picking a colour updates the DB, preserves alpha, and doesn't mutate defaults", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")
        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")

        local swatch = _G["CrosshairsOptioncrossColorSwatch"]
        T.AssertTrue(swatch ~= nil, "cross colour swatch was not created")

        swatch._scripts.OnClick(swatch) -- opens the picker, capturing the current colour
        addon.env.ColorPickerFrame._r = 0.1
        addon.env.ColorPickerFrame._g = 0.2
        addon.env.ColorPickerFrame._b = 0.3
        addon.env.ColorPickerFrame._info.swatchFunc() -- simulates the user confirming a pick

        local picked = addon.env.CrosshairsDB.crossColor
        T.AssertEqual(picked.r, 0.1)
        T.AssertEqual(picked.g, 0.2)
        T.AssertEqual(picked.b, 0.3)
        T.AssertEqual(picked.a, addon.ns.defaults.crossColor.a, "alpha should carry over unchanged")
        T.AssertEqual(addon.ns.defaults.crossColor.r, 0.5, "picking a colour must not mutate the shared default")
    end)
end
