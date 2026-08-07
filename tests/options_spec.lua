-- options_spec.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- Colour swatches and strata (#16): picking a colour updates the DB without corrupting
-- the shared defaults table, and the cross is raised to the circle's strata.

return function(stub, T)
    print("options:")

    T.Test("panel content lives in a scroll frame so it can't overflow the settings canvas (#51)", function()
        stub.LoadAddon(".", "Crosshairs.toc")
        local scrollFrame = _G["CrosshairsOptionsScrollFrame"]
        T.AssertTrue(scrollFrame ~= nil, "options scroll frame was not created")
        local scrollChild = scrollFrame._scrollChild
        T.AssertTrue(scrollChild ~= nil, "scroll frame has no scroll child set")

        -- Widgets built after the scroll frame (checkboxes, sliders, swatches, the reset
        -- button) must actually be parented inside it, not left on the fixed header.
        local swatch = _G["CrosshairsOptioncrossColorSwatch"]
        T.AssertEqual(swatch._parent, scrollChild, "cross colour swatch is not parented to the scroll child")
    end)

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

    -- On a client where neither slider template resolves (Blizzard has repeatedly renamed
    -- or removed them, #18), the panel used to abort mid-build: AddSlider read Low/High/Text
    -- off the template and indexed them unconditionally, so the very first slider after the
    -- Cross checkboxes raised and silently took every widget after it down with it -- headings,
    -- sliders, colour swatches, the whole Circle/Other sections and the reset button all
    -- missing, with only the checkboxes built before the crash actually showing.
    T.Test("the panel still builds completely when no slider or checkbox template resolves", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc", {
            blockedTemplates = {
                UICheckButtonTemplate = true,
                InterfaceOptionsCheckButtonTemplate = true,
                UISliderTemplateWithLabels = true,
                OptionsSliderTemplate = true,
            },
        })
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")
        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")

        -- Widgets from every section, including ones built well after the first slider,
        -- must all exist -- proof the file ran to completion instead of aborting partway.
        T.AssertTrue(_G["CrosshairsOptioncrossColorSwatch"] ~= nil, "cross colour swatch missing")
        T.AssertTrue(_G["CrosshairsOptioncircleColorSwatch"] ~= nil, "circle colour swatch missing")
        T.AssertTrue(addon.ns.optionsPanel ~= nil, "options panel was never registered")
    end)
end
