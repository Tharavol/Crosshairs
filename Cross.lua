-- Cross.lua
-- SPDX-License-Identifier: GPL-3.0
-- Draws the crosshair at the center of the screen.

local _, ns = ...
local defaults = ns.defaults

local frame = CreateFrame("Frame", "CrosshairsFrame", UIParent)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetSize(100, 100)
frame:SetFrameStrata("BACKGROUND")
frame:EnableMouse(false)
ns.crossFrame = frame

local horiz = frame:CreateTexture(nil, "ARTWORK")
horiz:SetColorTexture(0.5, 0.05, 0.05, 1) -- dark red
horiz:SetSize(50, 2) -- 50 pixels long, 2 pixels thick
horiz:SetPoint("CENTER", frame, "CENTER", 0, 0)

local vert = frame:CreateTexture(nil, "ARTWORK")
vert:SetColorTexture(0.5, 0.05, 0.05, 1) -- dark red
vert:SetSize(2, 50) -- 2 pixels thick, 50 pixels long
vert:SetPoint("CENTER", frame, "CENTER", 0, 0)

-- apply cross size/thickness based on settings
local function ApplyCrossSettings()
    local size = tonumber(CrosshairsDB.crossSize or defaults.crossSize)
    local thickness = tonumber(CrosshairsDB.crossThickness or defaults.crossThickness)
    if size and thickness then
        horiz:SetSize(size, thickness)
        vert:SetSize(thickness, size)
    end
end
ns.ApplyCrossSettings = ApplyCrossSettings
