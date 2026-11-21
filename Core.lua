-- Core.lua
-- SPDX-License-Identifier: GPL-3.0
-- Crosshairs addon: saved variables, shared namespace, and the login/combat event handling.
-- Cross.lua and Circle.lua register their frames into `ns` (crossFrame/circleFrame) and
-- their per-feature apply functions; this file only knows about the shared shapes.

local ADDON_NAME, ns = ...
ns.ADDON_NAME = ADDON_NAME

-- print() with the addon's coloured prefix.
local PREFIX = "|cff6699ffCrosshairs|r: "
function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

-- Version with exactly one leading "v" (release tags already carry one). An unsubstituted
-- version token (running from a git checkout) reports as "dev".
function ns.GetAddonVersion()
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    if not version or version == "" or version:match("^@.*@$") then
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
    circleBaseRadius = 28, -- pixels, as labelled (#7)
    circleSegments = 200, -- more => smoother; kept under the cap in ns.limits below
    circleLineThickness = 1,
    -- cross appearance defaults
    crossSize = 50,       -- leg length in pixels
    crossThickness = 2,   -- thickness in pixels
    -- Colour tables are shared by reference with CrosshairsDB (ApplyDefaults doesn't deep
    -- copy), so a colour change must store a new table, never mutate this one (#16).
    crossColor = { r = 0.5, g = 0.05, b = 0.05, a = 1 },  -- dark red
    circleColor = { r = 0.6, g = 0.8, b = 1, a = 1 },     -- light blue
}
local defaults = ns.defaults

-- Bounds shared by the sliders and slash setters. The circleSegments cap matters most:
-- every segment is a texture redrawn each tick, and a huge saved value hangs every login.
ns.limits = {
    circleSegments      = { min = 8, max = 256 },
    circleBaseRadius    = { min = 4, max = 150 },
    circleLineThickness = { min = 1, max = 20 },
    crossSize           = { min = 4, max = 200 },
    crossThickness      = { min = 1, max = 30 },
}

-- Clamps and rounds a value into `key`'s range. Returns the value and whether it was
-- adjusted, or nil for non-numeric input.
function ns.ClampSetting(key, value)
    local number = tonumber(value)
    if not number then return nil end
    local limit = ns.limits[key]
    if not limit then return number, false end
    local clamped = math.floor(math.max(limit.min, math.min(limit.max, number)) + 0.5)
    return clamped, clamped ~= number
end

-- Fills missing settings and clamps saved values, which may predate the limits.
local function ApplyDefaults()
    for k, v in pairs(defaults) do
        if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
    end
    for k in pairs(ns.limits) do
        CrosshairsDB[k] = ns.ClampSetting(k, CrosshairsDB[k]) or defaults[k]
    end
end
ns.ApplyDefaults = ApplyDefaults

-- Shared by the options panel's reset button and "/crosshairs reset".
function ns.ResetToDefaults()
    for k, v in pairs(defaults) do CrosshairsDB[k] = v end
    ns.optionsPanel.RefreshWidgets()
    ns.BuildCircleLines()
    ns.ApplyCrossSettings()
    ns.ApplyCombatState()
    ns.Print("settings reset to defaults")
end

-- Debug dot at the tracked cursor position. Only ns.SetDebugMode shows or hides it.
local debugDot = CreateFrame("Frame", "CrosshairsDebugDot", UIParent)
debugDot:SetSize(8, 8)
local ddTex = debugDot:CreateTexture(nil, "OVERLAY")
ddTex:SetColorTexture(0, 1, 0, 1)
ddTex:SetAllPoints(true)
debugDot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
debugDot:Hide()

local function TrackCursor(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetScale() or 1
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

-- The single place debug mode becomes visible state. OnUpdate is attached only while
-- shown, since a hidden frame gets no OnUpdate with which to show itself again.
function ns.SetDebugMode(enabled)
    CrosshairsDB.debugMode = enabled and true or false
    if CrosshairsDB.debugMode then
        debugDot:SetScript("OnUpdate", TrackCursor)
        TrackCursor(debugDot) -- place it before the first tick so it doesn't flash at centre
        debugDot:Show()
    else
        debugDot:SetScript("OnUpdate", nil)
        debugDot:Hide()
    end
end

function ns.ApplyCombatState()
    local db = CrosshairsDB
    local inCombat = InCombatLockdown()
    local showCross, showCircle
    if inCombat then
        showCross, showCircle = db.crossInCombat, db.circleInCombat
    else
        showCross, showCircle = db.crossOutOfCombat, db.circleOutOfCombat
    end
    ns.crossFrame:SetShown(showCross and not db.forceOff)
    ns.circleFrame:SetShown(showCircle and not db.forceOff)
end

-- Event frame for login, combat events, and addon load
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        ApplyDefaults()
        ns.BuildCircleLines()
        ns.ApplyCrossSettings()
        ns.ApplyCombatState()
        ns.optionsPanel.RefreshWidgets()
    elseif event == "PLAYER_LOGIN" then
        ns.BuildCircleLines()
        ns.ApplyCombatState()
        ns.SetDebugMode(CrosshairsDB.debugMode) -- restore the saved state across /reload
        ns.Print(ns.GetAddonVersion() .. " loaded. Type /crosshairs options to configure.")
    else
        ns.ApplyCombatState()
    end
end)
