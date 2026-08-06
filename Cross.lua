-- Cross.lua
-- SPDX-License-Identifier: GPL-3.0
-- Draws the crosshair at the center of the screen.

local _, ns = ...
local defaults = ns.defaults

local frame = CreateFrame("Frame", "CrosshairsFrame", UIParent)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetSize(100, 100)
frame:SetFrameStrata("MEDIUM") -- was BACKGROUND, which let ordinary UI (action bars, a
                                -- centred nameplate) occlude it; matches the circle (#16)
frame:EnableMouse(false)
ns.crossFrame = frame

-- Creation-time placeholders, same as the hardcoded size below -- ApplyCrossSettings
-- overwrites both with the real stored (or default) values at ADDON_LOADED.
local horiz = frame:CreateTexture(nil, "ARTWORK")
horiz:SetColorTexture(0.5, 0.05, 0.05, 1)
horiz:SetSize(50, 2) -- 50 pixels long, 2 pixels thick
horiz:SetPoint("CENTER", frame, "CENTER", 0, 0)

local vert = frame:CreateTexture(nil, "ARTWORK")
vert:SetColorTexture(0.5, 0.05, 0.05, 1)
vert:SetSize(2, 50) -- 2 pixels thick, 50 pixels long
vert:SetPoint("CENTER", frame, "CENTER", 0, 0)

-- apply cross size, thickness and colour based on settings
local function ApplyCrossSettings()
    local size = tonumber(CrosshairsDB.crossSize or defaults.crossSize)
    local thickness = tonumber(CrosshairsDB.crossThickness or defaults.crossThickness)
    if size and thickness then
        horiz:SetSize(size, thickness)
        vert:SetSize(thickness, size)
    end

    local color = CrosshairsDB.crossColor or defaults.crossColor
    horiz:SetColorTexture(color.r, color.g, color.b, color.a)
    vert:SetColorTexture(color.r, color.g, color.b, color.a)
end
ns.ApplyCrossSettings = ApplyCrossSettings
