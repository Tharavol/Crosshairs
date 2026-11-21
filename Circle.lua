-- Circle.lua
-- SPDX-License-Identifier: GPL-3.0
-- Draws the cursor-tracking circle. It brightens clockwise from the top based on
-- cast/global-cooldown progress, and expands while the Alt key is held.

local _, ns = ...
local defaults = ns.defaults

-- Spell 61304 is the global cooldown itself; its cooldown is the current GCD.
local GCD_SPELL_ID = 61304

local ALT_EXPAND_FACTOR = 1.8      -- radius multiplier while Alt is held
local FRAME_SIZE_PADDING = 8       -- keeps the outermost segment from clipping at the frame edge
local UPDATE_THROTTLE_SECONDS = 0.03 -- segment redraw rate; cursor tracking runs every frame
-- Alpha range a segment fades across as progress reaches it, and the widest fade span.
local MIN_ALPHA, MAX_ALPHA = 0.08, 1.00
local MAX_FADE_RANGE = 0.35

local circleFrame = CreateFrame("Frame", "CrosshairsCircle", UIParent)
circleFrame:SetSize(10, 10)
circleFrame:SetFrameStrata("MEDIUM") -- above background UI elements
circleFrame:EnableMouse(false)
ns.circleFrame = circleFrame

local circleTextures = {}

-- cos/sin per segment, computed on rebuild rather than every tick.
local segmentAngles = {}

-- Last anchored radius/count; segments are re-anchored only when either changes.
local lastGeometryN, lastGeometryRadius

local function GetSegmentSize(thickness)
    return math.max(2, math.min(10, math.floor(math.max(1, thickness) * 2)))
end

local function GetSegmentCount()
    return ns.ClampSetting("circleSegments", CrosshairsDB.circleSegments) or defaults.circleSegments
end

local function AcquireTexture(i)
    local tex = circleTextures[i]
    if not tex then
        tex = circleFrame:CreateTexture(nil, "ARTWORK")
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
        -- Colour is set here once; ticks only change SetAlpha, which multiplies on top.
        local color = CrosshairsDB.circleColor or defaults.circleColor
        tex:SetColorTexture(color.r, color.g, color.b, color.a)
        tex:Show()
        local angle = (math.pi / 2) - (i - 1) * (2 * math.pi / n)
        segmentAngles[i] = { cos = math.cos(angle), sin = math.sin(angle) }
    end
    for i = n + 1, #circleTextures do
        circleTextures[i]:Hide()
    end
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

local function GetGCDFraction()
    local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
    -- Only an explicit isEnabled == false suppresses it; the field is absent on some paths.
    if not info or info.isEnabled == false or info.startTime <= 0 or info.duration <= 0 then
        return nil
    end
    local elapsed = GetTime() - info.startTime
    if elapsed >= 0 and elapsed <= info.duration then
        return elapsed / info.duration
    end
    return nil
end

local function GetCircleProgress()
    return GetActiveCastFraction() or GetGCDFraction() or 0
end

-- Re-anchors segments only when geometry changed; alpha is updated every tick.
local function updateCirclePositions(radius, progress)
    local n = GetSegmentCount()
    local minAlpha, maxAlpha = MIN_ALPHA, MAX_ALPHA
    local fadeRange = math.min(10 / n, MAX_FADE_RANGE)

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

-- Cursor tracking runs every frame so the circle doesn't trail the cursor; segment
-- redraws are throttled.
local updateTimer = 0
circleFrame:SetScript("OnUpdate", function(self, elapsed)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetScale() or 1
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

    updateTimer = updateTimer + elapsed
    if updateTimer < UPDATE_THROTTLE_SECONDS then return end
    updateTimer = 0

    local alt = IsAltKeyDown() and ALT_EXPAND_FACTOR or 1.0
    local radius = (CrosshairsDB.circleBaseRadius or defaults.circleBaseRadius) * alt
    local size = math.ceil(radius * 2 + FRAME_SIZE_PADDING)
    self:SetSize(size, size)
    updateCirclePositions(radius, GetCircleProgress())
end)
