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

local function AddHeading(text)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
    fs:SetText(text)
    anchor = fs
    return fs
end

local function AddCheckbox(label, tooltip, dbKey, onChange)
    local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    cb.Text:SetText(label)
    cb.tooltipText = tooltip
    cb:SetScript("OnClick", function(self)
        CrosshairsDB[dbKey] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    table.insert(widgets, function()
        cb:SetChecked(CrosshairsDB[dbKey] and true or false)
    end)
    anchor = cb
    return cb
end

-- Bounds come from ns.limits (Core.lua) so the sliders and the slash setters enforce
-- one shared range; see the comment there for why the caps exist.
local function AddSlider(label, dbKey, step, onChange)
    local minV, maxV = ns.limits[dbKey].min, ns.limits[dbKey].max
    local name = "CrosshairsOption" .. dbKey .. "Slider"
    local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 8, -24)
    slider:SetWidth(260)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    _G[name .. "Low"]:SetText(minV)
    _G[name .. "High"]:SetText(maxV)
    local text = _G[name .. "Text"]
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
    anchor = slider
    return slider
end

AddHeading("Cross")
AddCheckbox("Show in combat", "Show the center cross while in combat.", "crossInCombat", ns.ApplyCombatState)
AddCheckbox("Show out of combat", "Show the center cross while out of combat.", "crossOutOfCombat", ns.ApplyCombatState)
AddSlider("Cross size", "crossSize", 1, function() ns.ApplyCrossSettings() end)
AddSlider("Cross thickness", "crossThickness", 1, function() ns.ApplyCrossSettings() end)

AddHeading("Cursor Circle")
AddCheckbox("Show in combat", "Show the cursor circle while in combat.", "circleInCombat", ns.ApplyCombatState)
AddCheckbox("Show out of combat", "Show the cursor circle while out of combat.",
    "circleOutOfCombat", ns.ApplyCombatState)
AddSlider("Base radius", "circleBaseRadius", 1, nil)
AddSlider("Segments", "circleSegments", 1, function() ns.BuildCircleLines() end)
AddSlider("Line thickness", "circleLineThickness", 1, function() ns.BuildCircleLines() end)

AddHeading("Other")
AddCheckbox("Debug mode",
    "Show a cursor-tracking debug dot and print diagnostic messages when settings change.",
    "debugMode", function() ns.SetDebugMode(CrosshairsDB.debugMode) end)

local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetButton:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -8, -24)
resetButton:SetSize(140, 22)
resetButton:SetText("Reset to Defaults")
resetButton:SetScript("OnClick", function()
    for k, v in pairs(ns.defaults) do CrosshairsDB[k] = v end
    for _, refresh in ipairs(widgets) do refresh() end
    ns.BuildCircleLines()
    ns.ApplyCrossSettings()
    ns.ApplyCombatState()
    print("Crosshairs: settings reset to defaults")
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
