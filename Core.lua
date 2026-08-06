-- Core.lua
-- SPDX-License-Identifier: GPL-3.0
-- Crosshairs addon: saved variables, shared namespace, and the login/combat event handling.
-- Cross.lua and Circle.lua register their frames into `ns` (crossFrame/circleFrame) and
-- their per-feature apply functions; this file only knows about the shared shapes.

local ADDON_NAME, ns = ...
ns.ADDON_NAME = ADDON_NAME

-- Returns a display-ready version string with exactly one leading "v".
-- The packager substitutes `@project-version@` in the TOC with the release tag, which
-- already carries a "v" (e.g. "v1.2.4"), so callers must not prefix one themselves --
-- that is how "Crosshairs vv1.2.3 loaded" reached the login message. Running from a git
-- clone leaves the token unsubstituted; report that as "dev" rather than printing it raw.
function ns.GetAddonVersion()
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = getMeta and getMeta(ADDON_NAME, "Version")
    if type(version) ~= "string" or version == "" or version:match("^@.*@$") then
        return "dev"
    end
    if not version:match("^[vV]") then
        version = "v" .. version
    end
    return version
end

-- Saved variables defaults (won't overwrite user settings)
CrosshairsDB = CrosshairsDB or {}
ns.defaults = {
    crossInCombat = true,
    crossOutOfCombat = true,
    circleInCombat = false,
    circleOutOfCombat = true,
    circleBaseRadius = 40,
    circleSegments = 200, -- more => smoother; kept well under the slider cap (see Options.lua)
    circleLineThickness = 1,
    -- cross appearance defaults
    crossSize = 50,       -- leg length in pixels
    crossThickness = 2,   -- thickness in pixels
}
local defaults = ns.defaults

-- scale applied to the base radius (30% smaller -> scale 0.7)
ns.circleScale = 0.7
for k, v in pairs(defaults) do
    if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
end

-- Debug cursor dot: shows a marker at the tracked cursor position when debug mode is enabled
local debugDot = CreateFrame("Frame", "CrosshairsDebugDot", UIParent)
ns.debugDot = debugDot
debugDot:SetSize(8, 8)
local ddTex = debugDot:CreateTexture(nil, "OVERLAY")
ddTex:SetColorTexture(0, 1, 0, 1)
ddTex:SetAllPoints(true)
debugDot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
debugDot:Hide()
debugDot:SetScript("OnUpdate", function(self)
    if CrosshairsDB.debugMode then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetScale() or 1
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        self:Show()
    else
        self:Hide()
    end
end)

-- Visibility control based on combat state and settings
function ns.ApplyCombatState()
    local crossFrame = ns.crossFrame
    local circleFrame = ns.circleFrame
    if CrosshairsDB.forceOff then
        if crossFrame then crossFrame:Hide() end
        if circleFrame then circleFrame:Hide() end
        return
    end

    local inCombat = InCombatLockdown() or false
    if inCombat then
        if crossFrame then
            if CrosshairsDB.crossInCombat then crossFrame:Show() else crossFrame:Hide() end
        end
        if circleFrame then
            if CrosshairsDB.circleInCombat then circleFrame:Show() else circleFrame:Hide() end
        end
    else
        if crossFrame then
            if CrosshairsDB.crossOutOfCombat then crossFrame:Show() else crossFrame:Hide() end
        end
        if circleFrame then
            if CrosshairsDB.circleOutOfCombat then circleFrame:Show() else circleFrame:Hide() end
        end
    end
end

-- Event frame for login, combat events, and addon load
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if (tostring(arg1) or ""):lower() ~= ADDON_NAME:lower() then return end
        for k, v in pairs(defaults) do
            if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
        end
        if ns.BuildCircleLines then ns.BuildCircleLines() end
        if ns.ApplyCrossSettings then ns.ApplyCrossSettings() end
        ns.ApplyCombatState()
        if ns.optionsPanel and ns.optionsPanel.RefreshWidgets then ns.optionsPanel.RefreshWidgets() end
    elseif event == "PLAYER_LOGIN" then
        for k, v in pairs(defaults) do
            if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
        end
        if ns.BuildCircleLines then ns.BuildCircleLines() end
        ns.ApplyCombatState()
        print("Crosshairs " .. ns.GetAddonVersion() .. " loaded. Type /crosshairs options to configure.")
    else
        ns.ApplyCombatState()
    end
end)
