-- combat_spec.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- ApplyCombatState visibility across the in-combat/out-of-combat setting combinations,
-- plus forceOff. Both crossFrame and circleFrame are exported on `ns`, so no stub of the
-- addon's own logic is needed here -- just of InCombatLockdown.

return function(stub, T)
    print("combat:")

    local function LoggedInAddon()
        local addon = stub.LoadAddon(".", "Crosshairs.toc")
        local eventFrame = stub.FindFrame(addon.frames, "ADDON_LOADED")
        eventFrame._scripts.OnEvent(eventFrame, "ADDON_LOADED", "Crosshairs")
        return addon
    end

    local combos = {
        { inCombat = true,  crossIn = true,  crossOut = true,  expectCross = true },
        { inCombat = true,  crossIn = false, crossOut = true,  expectCross = false },
        { inCombat = false, crossIn = true,  crossOut = true,  expectCross = true },
        { inCombat = false, crossIn = true,  crossOut = false, expectCross = false },
    }

    for i, combo in ipairs(combos) do
        T.Test("cross visibility combo " .. i, function()
            local addon = LoggedInAddon()
            addon.env.CrosshairsDB.crossInCombat = combo.crossIn
            addon.env.CrosshairsDB.crossOutOfCombat = combo.crossOut
            addon.api.combat = combo.inCombat

            addon.ns.ApplyCombatState()

            T.AssertEqual(addon.ns.crossFrame._shown, combo.expectCross)
        end)
    end

    T.Test("forceOff hides both regardless of combat settings", function()
        local addon = LoggedInAddon()
        addon.env.CrosshairsDB.forceOff = true
        addon.env.CrosshairsDB.crossInCombat = true
        addon.env.CrosshairsDB.crossOutOfCombat = true
        addon.api.combat = false

        addon.ns.ApplyCombatState()

        T.AssertEqual(addon.ns.crossFrame._shown, false)
        T.AssertEqual(addon.ns.circleFrame._shown, false)
    end)
end
