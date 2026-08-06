-- Core.lua
-- SPDX-License-Identifier: GPL-3.0
-- Crosshairs addon: saved variables, shared namespace, and the login/combat event handling.
-- Cross.lua and Circle.lua register their frames into `ns` (crossFrame/circleFrame) and
-- their per-feature apply functions; this file only knows about the shared shapes.

local ADDON_NAME, ns = ...
ns.ADDON_NAME = ADDON_NAME

-- Chat-output helper: every print() site retyped its own "Crosshairs: " prefix, and some
-- (status) had none at all. Joins arguments the same way print() does, so callers convert
-- by swapping the function name, and gives the addon's output a single, coloured, greppable
-- source marker in a busy chat frame.
local PREFIX = "|cff6699ffCrosshairs|r: "
function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

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
    -- 28, not 40: Circle.lua used to multiply this by a hidden 0.7 scale before drawing,
    -- so the slider labelled "Base radius: 40" actually drew a 28px radius (#7). The
    -- scale is gone; this is now the radius the slider says it is. Existing saved values
    -- above the default see a one-time increase to match -- accepted rather than migrated.
    circleBaseRadius = 28,
    circleSegments = 200, -- more => smoother; kept under the cap in ns.limits below
    circleLineThickness = 1,
    -- cross appearance defaults
    crossSize = 50,       -- leg length in pixels
    crossThickness = 2,   -- thickness in pixels
    -- Colours are tables rather than flat keys, per #16. Always replace this table
    -- wholesale when changing a colour (Options.lua's swatch does) rather than mutating
    -- its fields in place -- ApplyDefaults below copies the reference, not a deep copy,
    -- so an in-place mutation would corrupt this default too.
    crossColor = { r = 0.5, g = 0.05, b = 0.05, a = 1 },  -- dark red
    circleColor = { r = 0.6, g = 0.8, b = 1, a = 1 },     -- light blue
}
local defaults = ns.defaults

-- Bounds for every numeric setting, in one place so the options sliders and the slash
-- setters cannot disagree about them. circleSegments matters most: each segment is its
-- own texture redrawn every ~30ms, so an unclamped `/ch set segments 100000` hangs the
-- client, and because the value is saved it hangs again on every subsequent login. 256
-- already looks smooth, which is what makes it a cheap cap to accept.
ns.limits = {
    circleSegments      = { min = 8, max = 256 },
    circleBaseRadius    = { min = 4, max = 150 },
    circleLineThickness = { min = 1, max = 20 },
    crossSize           = { min = 4, max = 200 },
    crossThickness      = { min = 1, max = 30 },
}

-- Clamps a value into the range registered for `key` and rounds it to a whole number,
-- matching the step-1 sliders. Returns the usable number plus whether it differs from
-- what was asked for, so callers can tell the user their input was adjusted.
-- Returns nil for input that isn't a number at all.
function ns.ClampSetting(key, value)
    local number = tonumber(value)
    if not number then return nil end
    local limit = ns.limits[key]
    if not limit then return number, false end
    local clamped = math.floor(math.max(limit.min, math.min(limit.max, number)) + 0.5)
    return clamped, clamped ~= number
end

-- Fills in any missing setting and pulls saved values back inside ns.limits. The clamp
-- runs on load as well as on input: a profile saved before the setters were bounded can
-- still hold a value that would hang the client, and it has to be repaired before
-- BuildCircleLines reads it.
local function ApplyDefaults()
    for k, v in pairs(defaults) do
        if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
    end
    for k in pairs(ns.limits) do
        CrosshairsDB[k] = ns.ClampSetting(k, CrosshairsDB[k]) or defaults[k]
    end
end
ns.ApplyDefaults = ApplyDefaults

-- Debug cursor dot: shows a marker at the tracked cursor position when debug mode is enabled
-- Not exported on `ns`: visibility is owned by ns.SetDebugMode below, and handing the
-- frame out is what let callers Show() it directly. It keeps its global name so it can
-- still be inspected in-game via /framestack.
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

-- Attaches the tracking script only while debug mode is on, and is the single place that
-- turns the setting into visible state -- the slash command, the options checkbox and
-- login all route through here.
--
-- The previous version installed OnUpdate permanently and had it poll the flag to show or
-- hide the frame, which cannot work: WoW does not run OnUpdate on a hidden frame, so once
-- hidden the dot could never show itself again. It appeared at all only because the two
-- toggles called Show() directly, which meant a saved `debugMode = true` was dropped on
-- every /reload until you toggled it off and on again.
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
        ApplyDefaults()
        if ns.BuildCircleLines then ns.BuildCircleLines() end
        if ns.ApplyCrossSettings then ns.ApplyCrossSettings() end
        ns.ApplyCombatState()
        if ns.optionsPanel and ns.optionsPanel.RefreshWidgets then ns.optionsPanel.RefreshWidgets() end
    elseif event == "PLAYER_LOGIN" then
        if ns.BuildCircleLines then ns.BuildCircleLines() end
        ns.ApplyCombatState()
        ns.SetDebugMode(CrosshairsDB.debugMode) -- restore the saved state across /reload
        ns.Print(ns.GetAddonVersion() .. " loaded. Type /crosshairs options to configure.")
    else
        ns.ApplyCombatState()
    end
end)
