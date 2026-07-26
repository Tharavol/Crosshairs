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

-- Segments are small square textures; size scales with the configured line thickness.
-- Shared by BuildCircleLines (initial/settings-change build) and updateCirclePositions
-- (per-tick redraw) so the two never disagree on how big a segment should be.
local function GetSegmentSize(thickness)
    return math.max(2, math.min(10, math.floor(math.max(1, thickness) * 2)))
end

local function BuildCircleLines()
    local n = math.max(3, tonumber(CrosshairsDB.circleSegments or defaults.circleSegments))
    local thickness = tonumber(CrosshairsDB.circleLineThickness or defaults.circleLineThickness)
    local segSize = GetSegmentSize(thickness)
    for i = 1, n do
        if not circleTextures[i] then
            circleTextures[i] = circleFrame:CreateTexture(nil, "OVERLAY")
            circleTextures[i]:SetColorTexture(0.4, 0.6, 1, 0.95)
            if circleTextures[i].SetDrawLayer then circleTextures[i]:SetDrawLayer("ARTWORK", 0) end
        end
        circleTextures[i]:SetSize(segSize, segSize)
        circleTextures[i]:Show()
    end
    for i = n + 1, #circleTextures do
        if circleTextures[i] then circleTextures[i]:Hide() end
    end
    if CrosshairsDB.debugMode then
        print("Crosshairs: circle rebuilt with", n, "segments, segment size", segSize)
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
    if type(GetSpellCooldown) ~= "function" then
        return nil
    end
    local startTime, duration, enabled = GetSpellCooldown(GCD_SPELL_ID)
    if enabled and duration and duration > 0 and startTime and startTime > 0 then
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

local function updateCirclePositions(radius, progress)
    local n = math.max(3, tonumber(CrosshairsDB.circleSegments or defaults.circleSegments))
    local thickness = tonumber(CrosshairsDB.circleLineThickness or defaults.circleLineThickness)
    local segSize = GetSegmentSize(thickness)
    local minAlpha = 0.08
    local maxAlpha = 1.00
    local fadeRange = math.min(10 / n, 0.35)

    for i = 1, n do
        local tex = circleTextures[i]
        if not tex then
            tex = circleFrame:CreateTexture(nil, "OVERLAY")
            if tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK", 0) end
            tex:Show()
            circleTextures[i] = tex
        end

        tex:SetSize(segSize, segSize)
        local angle = (math.pi / 2) - (i - 1) * (2 * math.pi / n)
        tex:SetPoint("CENTER", circleFrame, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)

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
        tex:SetColorTexture(0.6, 0.8, 1, alpha)
    end
end

local updateTimer = 0
circleFrame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.03 then return end
    updateTimer = 0

    local x, y = GetCursorPosition()
    local scale = UIParent:GetScale() or 1
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

    local alt = IsAltKeyDown() and 1.8 or 1.0
    local radius = (CrosshairsDB.circleBaseRadius or defaults.circleBaseRadius) * circleScale * alt
    local size = math.ceil(radius * 2 + 8)
    self:SetSize(size, size)
    updateCirclePositions(radius, GetCircleProgress())
end)

-- Build immediately so the circle uses stored values on load, without waiting for PLAYER_LOGIN
pcall(BuildCircleLines)
