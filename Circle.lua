-- Circle.lua
-- SPDX-License-Identifier: GPL-3.0
-- Draws the cursor-tracking circle. It brightens clockwise from the top based on
-- cast/global-cooldown progress, and expands while the Alt key is held.

local _, ns = ...
local defaults = ns.defaults
local circleScale = ns.circleScale

-- 61304 is a placeholder spell every class/spec can query; GetSpellCooldown on it reports
-- the shared global cooldown rather than any particular ability's cooldown.
local GCD_SPELL_ID = 61304

local circleFrame = CreateFrame("Frame", "CrosshairsCircle", UIParent)
circleFrame:SetSize(10, 10)
circleFrame:SetFrameStrata("MEDIUM") -- above background UI elements
circleFrame:EnableMouse(false)
ns.circleFrame = circleFrame

local circleTextures = {}

-- cos/sin per segment, indexed the same as circleTextures. Segment angle only depends on
-- the segment count, so this is computed once on rebuild instead of every tick.
local segmentAngles = {}

-- The radius/count updateCirclePositions last anchored textures at, so a tick where
-- neither changed can skip SetPoint entirely -- the frame itself still tracks the cursor
-- every frame (see OnUpdate below), so segments don't need re-anchoring to follow it.
local lastGeometryN, lastGeometryRadius

-- Segments are small square textures; size scales with the configured line thickness.
local function GetSegmentSize(thickness)
    return math.max(2, math.min(10, math.floor(math.max(1, thickness) * 2)))
end

-- Defers to ns.limits rather than carrying its own floor, so this file can't disagree
-- with the sliders and slash setters about how few segments are allowed. The DB is
-- already clamped on load and on every change, so this only bites if something writes
-- CrosshairsDB directly.
local function GetSegmentCount()
    return ns.ClampSetting("circleSegments", CrosshairsDB.circleSegments) or defaults.circleSegments
end

-- Shared by BuildCircleLines and updateCirclePositions so the two can't drift the way the
-- segment-size formulas did in 1.2.2 -- there is exactly one place a segment texture gets
-- created.
local function AcquireTexture(i)
    local tex = circleTextures[i]
    if not tex then
        tex = circleFrame:CreateTexture(nil, "OVERLAY")
        if tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK", 0) end
        circleTextures[i] = tex
    end
    return tex
end

local function BuildCircleLines()
    local n = GetSegmentCount()
    local thickness = tonumber(CrosshairsDB.circleLineThickness or defaults.circleLineThickness)
    local segSize = GetSegmentSize(thickness)
    for i = 1, n do
        local tex = AcquireTexture(i)
        tex:SetSize(segSize, segSize)
        -- Colour is set once here; only alpha varies per tick, in updateCirclePositions.
        tex:SetColorTexture(0.6, 0.8, 1, 1)
        tex:Show()
        local angle = (math.pi / 2) - (i - 1) * (2 * math.pi / n)
        segmentAngles[i] = { cos = math.cos(angle), sin = math.sin(angle) }
    end
    for i = n + 1, #circleTextures do
        if circleTextures[i] then circleTextures[i]:Hide() end
    end
    -- Geometry just changed under whatever radius the next tick reads; force it to
    -- re-anchor every segment instead of trusting a stale lastGeometryRadius match.
    lastGeometryN, lastGeometryRadius = nil, nil
    if CrosshairsDB.debugMode then
        ns.Print("circle rebuilt with", n, "segments, segment size", segSize)
    end
end
ns.BuildCircleLines = BuildCircleLines

local function GetActiveCastFraction()
    local name, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
    if name and startTimeMS and endTimeMS and endTimeMS > startTimeMS then
        return math.min(1, math.max(0, (GetTime() * 1000 - startTimeMS) / (endTimeMS - startTimeMS)))
    end
    name, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
    if name and startTimeMS and endTimeMS and endTimeMS > startTimeMS then
        return math.min(1, math.max(0, (GetTime() * 1000 - startTimeMS) / (endTimeMS - startTimeMS)))
    end
    return nil
end

-- Reads the global cooldown across both API generations. Retail 11.0+ replaced the
-- `startTime, duration, enabled` tuple with a single info table, so the old call put a
-- table in `startTime` and nil in the rest: the guard failed on every call and the
-- circle silently never tracked the GCD, only actual casts. No Lua error was raised,
-- which is why it went unnoticed.
local function GetGCDFraction()
    local startTime, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        -- isEnabled false means the cooldown shouldn't be displayed yet; absent on
        -- some paths, so only an explicit false suppresses it.
        if info and info.isEnabled ~= false then
            startTime, duration = info.startTime, info.duration
        end
    elseif type(GetSpellCooldown) == "function" then
        local enabled
        startTime, duration, enabled = GetSpellCooldown(GCD_SPELL_ID)
        if enabled == 0 then return nil end
    end

    if startTime and duration and startTime > 0 and duration > 0 then
        local elapsed = GetTime() - startTime
        if elapsed >= 0 and elapsed <= duration then
            return math.min(1, math.max(0, elapsed / duration))
        end
    end
    return nil
end

local function GetCircleProgress()
    return GetActiveCastFraction() or GetGCDFraction() or 0
end

-- Runs every throttled tick: geometry (SetPoint) only when radius or segment count
-- changed since last time, alpha (SetAlpha, not SetColorTexture -- colour is fixed at
-- build time) always, since progress can move every tick during a cast.
local function updateCirclePositions(radius, progress)
    local n = GetSegmentCount()
    local minAlpha = 0.08
    local maxAlpha = 1.00
    local fadeRange = math.min(10 / n, 0.35)

    local geometryChanged = n ~= lastGeometryN or radius ~= lastGeometryRadius
    lastGeometryN, lastGeometryRadius = n, radius

    for i = 1, n do
        local tex = circleTextures[i]

        if geometryChanged then
            local a = segmentAngles[i]
            tex:SetPoint("CENTER", circleFrame, "CENTER", a.cos * radius, a.sin * radius)
        end

        local segmentPos = (i - 1) / n
        local alpha = minAlpha
        if progress >= 1 then
            alpha = maxAlpha
        elseif progress > 0 then
            if segmentPos <= progress then
                alpha = maxAlpha
            elseif segmentPos <= progress + fadeRange then
                alpha = minAlpha + (maxAlpha - minAlpha) * (1 - (segmentPos - progress) / fadeRange)
            end
        end
        tex:SetAlpha(alpha)
    end
end

-- Cursor tracking (one SetPoint on the frame) runs every frame -- it used to share the
-- 30ms throttle below, which is why the circle visibly trailed the hardware cursor.
-- Segment appearance work stays throttled, since redrawing 200+ segments doesn't need
-- to happen faster than ~33x/sec.
local updateTimer = 0
circleFrame:SetScript("OnUpdate", function(self, elapsed)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetScale() or 1
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

    updateTimer = updateTimer + elapsed
    if updateTimer < 0.03 then return end
    updateTimer = 0

    local alt = IsAltKeyDown() and 1.8 or 1.0
    local radius = (CrosshairsDB.circleBaseRadius or defaults.circleBaseRadius) * circleScale * alt
    local size = math.ceil(radius * 2 + 8)
    self:SetSize(size, size)
    updateCirclePositions(radius, GetCircleProgress())
end)
