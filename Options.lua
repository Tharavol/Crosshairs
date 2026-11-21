-- Options.lua
-- SPDX-License-Identifier: GPL-3.0
-- Options panel: Game Menu (Esc) > Options > AddOns > Crosshairs

local _, ns = ...

local panel = CreateFrame("Frame")
panel.name = "Crosshairs"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Crosshairs")

local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
versionText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)
versionText:SetText(ns.GetAddonVersion())

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Draws a centered crosshair and a cursor circle that expands while Alt is held.")

-- The widget stack is taller than the settings canvas, so it scrolls (#51); the header
-- above stays fixed on `panel`.
local scrollFrame = CreateFrame("ScrollFrame", "CrosshairsOptionsScrollFrame", panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -27, 16) -- -27 clears the template's scrollbar

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(1, 1) -- height is set by ResizeScrollChild once the stack is built
scrollFrame:SetScrollChild(scrollChild)
scrollFrame:SetScript("OnSizeChanged", function(_, width) scrollChild:SetWidth(width) end)

-- Place() anchors each widget below the previous one; this marker is the first "previous".
local topMarker = CreateFrame("Frame", nil, scrollChild)
topMarker:SetSize(1, 1)
topMarker:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)

local widgets = {}
local anchor = topMarker
local anchorIndent = 0

-- `indent` is absolute from the content column, so indented runs don't accumulate (#49).
local function Place(widget, indent, gap)
    widget:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent - anchorIndent, -gap)
    anchor, anchorIndent = widget, indent
end

local function AddHeading(text)
    local fs = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    Place(fs, 0, 20)
    fs:SetText(text)
    return fs
end

-- The label and tooltip are built by hand: UICheckButtonTemplate's own text region is
-- not reliable across client versions.
local function AddCheckbox(label, tooltip, dbKey, onChange)
    local cb = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    Place(cb, 0, 8)

    local text = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)

    cb:SetScript("OnClick", function(self)
        CrosshairsDB[dbKey] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    table.insert(widgets, function()
        cb:SetChecked(CrosshairsDB[dbKey] and true or false)
    end)
    return cb
end

-- Bounds come from ns.limits so sliders and slash setters share one range.
local function AddSlider(label, dbKey, step, onChange)
    local minV, maxV = ns.limits[dbKey].min, ns.limits[dbKey].max
    local slider = CreateFrame("Slider", "CrosshairsOption" .. dbKey .. "Slider", scrollChild,
        "UISliderTemplateWithLabels")
    Place(slider, 8, 24)
    slider:SetWidth(260)
    slider:SetHeight(30) -- leaves room for the Low/High row so Place() clears it
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(minV)
    slider.High:SetText(maxV)

    local function UpdateLabel(value)
        slider.Text:SetText(label .. ": " .. tostring(value))
    end
    slider:SetScript("OnValueChanged", function(_, value)
        if step == 1 then value = math.floor(value + 0.5) end
        CrosshairsDB[dbKey] = value
        UpdateLabel(value)
        if onChange then onChange() end
    end)
    table.insert(widgets, function()
        local value = CrosshairsDB[dbKey] or minV
        slider:SetValue(value)
        UpdateLabel(value)
    end)
    return slider
end

-- ColorPickerFrame-backed swatch. Only RGB is edited (#16); the stored alpha is kept.
-- Always stores a new table rather than mutating in place: see the colour defaults in Core.lua.
local function AddColorSwatch(label, dbKey, onChange)
    local swatch = CreateFrame("Button", "CrosshairsOption" .. dbKey .. "Swatch", scrollChild)
    swatch:SetSize(20, 20)
    Place(swatch, 0, 8)

    local swatchTexture = swatch:CreateTexture(nil, "OVERLAY")
    swatchTexture:SetAllPoints(true)

    local text = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    text:SetText(label)

    local function CurrentColor()
        return CrosshairsDB[dbKey] or ns.defaults[dbKey]
    end

    local function SetColor(r, g, b)
        CrosshairsDB[dbKey] = { r = r, g = g, b = b, a = CurrentColor().a }
        swatchTexture:SetColorTexture(r, g, b, 1)
        if onChange then onChange() end
    end

    swatch:SetScript("OnClick", function()
        local color = CurrentColor()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r, g = color.g, b = color.b,
            swatchFunc = function() SetColor(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(previous)
                if previous then SetColor(previous.r, previous.g, previous.b) end
            end,
        })
    end)

    table.insert(widgets, function()
        local color = CurrentColor()
        swatchTexture:SetColorTexture(color.r, color.g, color.b, 1)
    end)

    return swatch
end

AddHeading("Cross")
AddCheckbox("Show in combat", "Show the center cross while in combat.", "crossInCombat", ns.ApplyCombatState)
AddCheckbox("Show out of combat", "Show the center cross while out of combat.", "crossOutOfCombat", ns.ApplyCombatState)
AddSlider("Cross size", "crossSize", 1, function() ns.ApplyCrossSettings() end)
AddSlider("Cross thickness", "crossThickness", 1, function() ns.ApplyCrossSettings() end)
AddColorSwatch("Cross colour", "crossColor", function() ns.ApplyCrossSettings() end)

AddHeading("Cursor Circle")
AddCheckbox("Show in combat", "Show the cursor circle while in combat.", "circleInCombat", ns.ApplyCombatState)
AddCheckbox("Show out of combat", "Show the cursor circle while out of combat.",
    "circleOutOfCombat", ns.ApplyCombatState)
AddSlider("Base radius", "circleBaseRadius", 1, nil)
AddSlider("Segments", "circleSegments", 1, function() ns.BuildCircleLines() end)
AddSlider("Line thickness", "circleLineThickness", 1, function() ns.BuildCircleLines() end)
AddColorSwatch("Circle colour", "circleColor", function() ns.BuildCircleLines() end)

AddHeading("Other")
AddCheckbox("Debug mode",
    "Show a cursor-tracking debug dot and print diagnostic messages when settings change.",
    "debugMode", function() ns.SetDebugMode(CrosshairsDB.debugMode) end)

local resetButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
Place(resetButton, 0, 24)
resetButton:SetSize(140, 22)
resetButton:SetText("Reset to Defaults")
resetButton:SetScript("OnClick", ns.ResetToDefaults)

-- Sizes the scroll child from the resolved layout (top of the stack to the bottom of the
-- reset button). Geometry is nil until the panel is laid out, hence the fixed fallback.
local function ResizeScrollChild()
    local top, bottom = scrollChild:GetTop(), anchor:GetBottom()
    scrollChild:SetHeight(top and bottom and (top - bottom) + 24 or 900)
end

function panel.RefreshWidgets()
    for _, refresh in ipairs(widgets) do refresh() end
end
panel:SetScript("OnShow", function()
    panel.RefreshWidgets()
    ResizeScrollChild()
end)

ns.optionsPanel = panel

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
ns.optionsCategoryID = category:GetID()
