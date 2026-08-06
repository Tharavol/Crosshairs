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

local widgets = {}
local anchor = subtitle
local anchorIndent = 0

-- `indent` is measured from the panel's content column (0 = flush with headings and
-- checkboxes) rather than from the previous widget's own position, so a run of indented
-- widgets -- the sliders -- can't accumulate offset down the page the way they used to
-- when each one anchored 8px right of whatever it followed (#49).
local function Place(widget, indent, gap)
    widget:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent - anchorIndent, -gap)
    anchor, anchorIndent = widget, indent
end

local function AddHeading(text)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    Place(fs, 0, 20)
    fs:SetText(text)
    return fs
end

-- CreateFrame raises immediately if `template` doesn't resolve on the running client,
-- taking the rest of this file's registration down with it (#18) -- so the modern
-- template is tried first and a known-good older one is the fallback, rather than
-- assuming success.
local function CreateFrameWithFallback(frameType, name, parent, template, fallbackTemplate)
    local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
    if ok and frame then return frame end
    return CreateFrame(frameType, name, parent, fallbackTemplate)
end

-- UICheckButtonTemplate (verified against MoxieTracker, Auctionator, TLDRMissions) does
-- not reliably expose a usable built-in text/tooltip region across client versions --
-- Auctionator and MoxieTracker both add their own label and wire OnEnter/OnLeave by
-- hand rather than relying on it, so this does the same instead of setting cb.Text /
-- cb.tooltipText the way the pre-10.0 InterfaceOptionsCheckButtonTemplate wanted.
local function AddCheckbox(label, tooltip, dbKey, onChange)
    local cb = CreateFrameWithFallback("CheckButton", nil, panel,
        "UICheckButtonTemplate", "InterfaceOptionsCheckButtonTemplate")
    cb:SetSize(24, 24)
    Place(cb, 0, 8)

    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
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

-- Bounds come from ns.limits (Core.lua) so the sliders and the slash setters enforce
-- one shared range; see the comment there for why the caps exist.
--
-- UISliderTemplateWithLabels (verified against WarbandMiser and DejaCharacterStats)
-- exposes Low/High/Text as direct fields (slider.Low) rather than the pre-10.0
-- OptionsSliderTemplate's globals ($parentLow via _G[name.."Low"]) -- try the field
-- first and fall back to the global so this works with whichever template resolved.
local function AddSlider(label, dbKey, step, onChange)
    local minV, maxV = ns.limits[dbKey].min, ns.limits[dbKey].max
    local name = "CrosshairsOption" .. dbKey .. "Slider"
    local slider = CreateFrameWithFallback("Slider", name, panel,
        "UISliderTemplateWithLabels", "OptionsSliderTemplate")
    Place(slider, 8, 24)
    slider:SetWidth(260)
    if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local low = slider.Low or _G[name .. "Low"]
    local high = slider.High or _G[name .. "High"]
    local text = slider.Text or _G[name .. "Text"]
    low:SetText(minV)
    high:SetText(maxV)
    local function UpdateLabel(value)
        text:SetText(label .. ": " .. tostring(value))
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

-- A small ColorPickerFrame-backed swatch. Alpha isn't exposed in the picker -- the
-- reported problem (#16) is hue/brightness, dark red over a dark floor is nearly
-- invisible, not transparency -- so only RGB round-trips through it; whatever alpha the
-- colour already has is preserved. Always replaces CrosshairsDB[dbKey] with a new table
-- rather than mutating the existing one in place; see the comment on the colour defaults
-- in Core.lua for why that matters.
local function AddColorSwatch(label, dbKey, onChange)
    local name = "CrosshairsOption" .. dbKey .. "Swatch"
    local swatch = CreateFrame("Button", name, panel)
    swatch:SetSize(20, 20)
    Place(swatch, 0, 8)

    local swatchTexture = swatch:CreateTexture(nil, "OVERLAY")
    swatchTexture:SetAllPoints(true)

    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    text:SetText(label)

    local function CurrentColor()
        return CrosshairsDB[dbKey] or ns.defaults[dbKey]
    end

    local function SetColor(r, g, b)
        local alpha = CurrentColor().a
        CrosshairsDB[dbKey] = { r = r, g = g, b = b, a = alpha }
        swatchTexture:SetColorTexture(r, g, b, 1)
        if onChange then onChange() end
    end

    swatch:SetScript("OnClick", function()
        if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
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

local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
Place(resetButton, 0, 24)
resetButton:SetSize(140, 22)
resetButton:SetText("Reset to Defaults")
resetButton:SetScript("OnClick", function()
    for k, v in pairs(ns.defaults) do CrosshairsDB[k] = v end
    for _, refresh in ipairs(widgets) do refresh() end
    ns.BuildCircleLines()
    ns.ApplyCrossSettings()
    ns.ApplyCombatState()
    ns.Print("settings reset to defaults")
end)

function panel.RefreshWidgets()
    for _, refresh in ipairs(widgets) do refresh() end
end
panel:SetScript("OnShow", panel.RefreshWidgets)

ns.optionsPanel = panel

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategoryID = category:GetID()
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end
