-- init_spec.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- ADDON_LOADED/PLAYER_LOGIN and version-string regression tests. The version check is a
-- standing regression test for #3 ("Crosshairs vv1.2.3 loaded"): the packager substitutes
-- a tag that already carries a "v", so GetAddonVersion must not prefix a second one.

return function(stub, T)
    print("init:")

    T.Test("ADDON_LOADED fills in defaults", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")
        T.AssertTrue(eventFrame ~= nil, "no frame registered ADDON_LOADED")

        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")

        T.AssertEqual(addon.env.CrosshairsDB.circleSegments, addon.ns.defaults.circleSegments)
        T.AssertEqual(addon.env.CrosshairsDB.crossSize, addon.ns.defaults.crossSize)
    end)

    T.Test("PLAYER_LOGIN prints a well-formed version, never a doubled v", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        addon.api.addonVersion = "1.2.4"
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")

        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")
        eventFrame._scripts.OnEvent(eventFrame, "PLAYER_LOGIN")

        local lastMessage = addon.api.chatLog[#addon.api.chatLog]
        T.AssertTrue(lastMessage ~= nil, "PLAYER_LOGIN printed nothing")
        T.AssertTrue(lastMessage:find("v1.2.4 loaded", 1, true) ~= nil,
            "expected a 'v1.2.4 loaded' message, got: " .. tostring(lastMessage))
        T.AssertTrue(lastMessage:find("vv", 1, true) == nil,
            "version string has a doubled v: " .. tostring(lastMessage))
    end)

    T.Test("an unresolved @project-version@ token reports as dev, not raw", function()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        addon.api.addonVersion = "@project-version@"
        T.AssertEqual(addon.ns.GetAddonVersion(), "dev")
    end)
end
