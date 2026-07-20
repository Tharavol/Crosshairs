-- crosshairs.lua
-- Crosshairs addon: draws a centered cross and a cursor circle that scales while Alt is pressed.

-- Saved variables defaults (won't overwrite user settings)
CrosshairsDB = CrosshairsDB or {}
local defaults = {
    crossInCombat = true,
    crossOutOfCombat = true,
    circleInCombat = false,
    circleOutOfCombat = true,
    circleBaseRadius = 40,
    circleSegments = 512, -- increased for smoother circle (more, smaller segments)
    circleLineThickness = 1,
    -- cross appearance defaults
    crossSize = 50,       -- leg length in pixels
    crossThickness = 2,   -- thickness in pixels
}

-- scale applied to the base radius (30% smaller -> scale 0.7)
local circleScale = 0.7
for k, v in pairs(defaults) do
    if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
end

-- forward declarations: the options panel is built further down (after the
-- functions it needs already exist), but the ADDON_LOADED handler above
-- references it, so it must be declared as an upvalue before that closure
-- is created.
local optionsPanel
local optionsCategoryID

-- Debug: indicate the file executed
if CrosshairsDB.debugMode then print("Crosshairs: crosshairs.lua executed") end

-- Temporary visible debug dot at screen center to verify the addon can draw UI elements
local debugDot = CreateFrame("Frame", "CrosshairsDebugDot", UIParent)
debugDot:SetSize(8, 8)
local ddTex = debugDot:CreateTexture(nil, "OVERLAY")
ddTex:SetColorTexture(0, 1, 0, 1)
ddTex:SetAllPoints(true)
debugDot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
debugDot:Hide() -- hidden by default; show when debug mode enabled
debugDot:SetScript("OnUpdate", function(self)
    if CrosshairsDB.debugMode then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetScale() or 1
        x = x / scale
        y = y / scale
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        if not self:IsShown() then
            self:Show()
            print("Crosshairs: debug dot visible and following cursor")
        end
    else
        if self:IsShown() then self:Hide() end
    end
end)

-- Cross (center of screen)
local frame = CreateFrame("Frame", "CrosshairsFrame", UIParent)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetSize(100, 100)
frame:SetFrameStrata("BACKGROUND")
frame:EnableMouse(false)

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
        if CrosshairsDB.debugMode then
            print("Crosshairs: ApplyCrossSettings size", size, "thickness", thickness)
        end
    end
end

-- Cursor circle (continuous) with dynamic rebuild
local circleFrame = CreateFrame("Frame", "CrosshairsCircle", UIParent)
circleFrame:SetSize(10, 10)
-- ensure visibility above background UI elements
circleFrame:SetFrameStrata("MEDIUM")
circleFrame:EnableMouse(false)
circleFrame:SetScript("OnShow", function()
    if CrosshairsDB.debugMode then print("Crosshairs: circleFrame shown") end
end)
circleFrame:SetScript("OnHide", function()
    if CrosshairsDB.debugMode then print("Crosshairs: circleFrame hidden") end
    -- print stack to see who hid us (debug only)
    if CrosshairsDB.debugMode then
        local ok, st = pcall(debugstack, 2, 10, 1)
        if ok and st then
            print("Crosshairs: circleFrame hidden; stack:\n" .. st)
        end
    end
    -- If this was during a forced test, try to re-show and warn
    if circleFrame._forceVisible then
        C_Timer.After(0.2, function()
            if circleFrame._forceVisible then
                if CrosshairsDB.debugMode then print("Crosshairs: Re-showing circleFrame because it was forced visible") end
                circleFrame:Show()
            end
        end)
    end
end)

local circleTextures = {}
local function BuildCircleLines()
    local n = math.max(3, tonumber(CrosshairsDB.circleSegments or defaults.circleSegments))
    local thickness = tonumber(CrosshairsDB.circleLineThickness or defaults.circleLineThickness)
    -- increase segment size so they're visible; cap to avoid overly large textures
    local segSize = math.max(2, math.min(8, math.floor(math.max(1, thickness) * 1.6)))
    for i = 1, n do
        if not circleTextures[i] then
            circleTextures[i] = circleFrame:CreateTexture(nil, "OVERLAY")
            circleTextures[i]:SetColorTexture(0.4, 0.6, 1, 0.95)
            circleTextures[i]:SetSize(segSize, segSize)
            if circleTextures[i].SetDrawLayer then circleTextures[i]:SetDrawLayer("ARTWORK", 0) end
        end
        circleTextures[i]:SetSize(segSize, segSize)
        circleTextures[i]:Show()
    end
    for i = n+1, #circleTextures do
        if circleTextures[i] then circleTextures[i]:Hide() end
    end
    -- debug: report configured vs actual texture count when debug mode enabled
    if CrosshairsDB.debugMode then
        local actualCount = 0
        for _ = 1, #circleTextures do actualCount = actualCount + 1 end
        local shown = 0
        for i = 1, n do if circleTextures[i] and circleTextures[i]:IsShown() then shown = shown + 1 end end
        print("Crosshairs: BuildCircleTextures requested", n, "actualTextures", actualCount, "shown", shown, "segSize", segSize)
    end
end

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
    local startTime, duration, enabled = GetSpellCooldown(61304)
    if enabled and duration and duration > 0 and startTime and startTime > 0 then
        local now = GetTime()
        local elapsed = now - startTime
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
    -- use configured segment count rather than relying on #circleTextures (keeps behavior stable)
    local n = math.max(3, tonumber(CrosshairsDB.circleSegments or defaults.circleSegments))
    if n < 3 then return end
    local thickness = tonumber(CrosshairsDB.circleLineThickness or defaults.circleLineThickness)
    local segSize = math.max(2, math.min(10, math.floor(math.max(1, thickness) * 2)))
    local minAlpha = 0.08
    local maxAlpha = 1.00
    local fadeRange = math.min(10 / n, 0.35)

    for i = 1, n do
        local tex = circleTextures[i]
        if not tex then
            tex = circleFrame:CreateTexture(nil, "OVERLAY")
            if tex and tex.SetDrawLayer then
                tex:SetDrawLayer("ARTWORK", 0)
            end
            if tex then
                tex:Show()
                circleTextures[i] = tex
            end
        end
        if not tex then
            if CrosshairsDB.debugMode then
                print("Crosshairs: failed to create circle texture at index", i)
            end
            return
        end

        tex:SetSize(segSize, segSize)
        local angle = (math.pi / 2) - (i - 1) * (2 * math.pi / n)
        local dx = math.cos(angle) * radius
        local dy = math.sin(angle) * radius
        if tex.SetPoint then
            tex:SetPoint("CENTER", circleFrame, "CENTER", dx, dy)
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

        if tex.SetColorTexture then
            tex:SetColorTexture(0.6, 0.8, 1, alpha)
        end
    end

    if CrosshairsDB.debugMode then
        print("Crosshairs: updateCirclePositions radius", radius, "segments", n, "progress", string.format("%.2f", progress), "frame shown", tostring(circleFrame:IsShown()))
        -- sample four quadrants to verify full coverage
        local samples = {1, math.floor(n/4)+1, math.floor(n/2)+1, math.floor(3*n/4)+1}
        for _, i in ipairs(samples) do
            local tex = circleTextures[i]
            if tex then
                local angle = (math.pi / 2) - (i - 1) * (2 * math.pi / n)
                local dx = math.cos(angle) * radius
                local dy = math.sin(angle) * radius
                print("  sample", i, "angle", string.format("%.2f", angle), "dx", string.format("%.1f", dx), "dy", string.format("%.1f", dy))
            else
                print("  sample", i, "missing texture")
            end
        end
    end
end

local updateTimer = 0
circleFrame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.03 then return end
    updateTimer = 0

    -- Cursor position in UI coordinates
    local x, y = GetCursorPosition()
    local scale = UIParent:GetScale() or 1
    x = x / scale
    y = y / scale
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

    local alt = IsAltKeyDown() and 1.8 or 1.0
    local radius = (CrosshairsDB.circleBaseRadius or defaults.circleBaseRadius) * circleScale * alt
    local progress = GetCircleProgress()
    -- Ensure the frame is large enough so segments aren't clipped
    local size = math.ceil(radius * 2 + 8)
    self:SetSize(size, size)
    updateCirclePositions(radius, progress)
    if CrosshairsDB.debugMode then
        -- show a small debug marker at first point
        local n = #circleTextures
        if n > 0 then
            local p = math.floor(n/2)+1
            print("Crosshairs: cursor at", x, y, "radius", radius, "first point", p)
        end
    end
end)

-- Visibility control based on combat state and settings
local function ApplyCombatState()
    if CrosshairsDB.forceOff then
        if frame then frame:Hide() end
        if circleFrame then circleFrame:Hide() end
        return
    end

    local inCombat = InCombatLockdown() or false
    -- If a test or circletest is forcing visibility, keep it visible
    if circleFrame._forceVisible then
        if circleFrame._forceVisible then circleFrame:Show() end
        if CrosshairsDB.crossInCombat or CrosshairsDB.crossOutOfCombat then frame:Show() end
        return
    end
    if inCombat then
        if CrosshairsDB.crossInCombat then frame:Show() else frame:Hide() end
        if CrosshairsDB.circleInCombat then circleFrame:Show() else circleFrame:Hide() end
    else
        if CrosshairsDB.crossOutOfCombat then frame:Show() else frame:Hide() end
        if CrosshairsDB.circleOutOfCombat then circleFrame:Show() else circleFrame:Hide() end
    end
    -- Debug: report current state (useful if circle not visible)
    if CrosshairsDB.circleInCombat or CrosshairsDB.circleOutOfCombat then
        -- Debug-only: report current state (useful if circle not visible)
        if CrosshairsDB.debugMode then
            if circleFrame and circleFrame.IsShown and circleFrame:IsShown() then
                print("Crosshairs: circle is currently shown")
            else
                print("Crosshairs: circle is configured to show but is not visible — check build/size")
            end
        end
    end
end

-- Event frame for login, combat events, and addon load
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if CrosshairsDB.debugMode then print("Crosshairs: ADDON_LOADED saw", tostring(arg1)) end
        local nameLower = (tostring(arg1) or ""):lower()
        if nameLower == "crosshairs" then
            if CrosshairsDB.debugMode then print("Crosshairs: ADDON_LOADED for 'crosshairs' (case-insensitive match)") end
            -- ensure defaults applied
            for k, v in pairs(defaults) do
                if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
            end
            BuildCircleLines()
            ApplyCrossSettings()
            ApplyCombatState()
            if optionsPanel and optionsPanel.RefreshWidgets then optionsPanel.RefreshWidgets() end
        end
    elseif event == "PLAYER_LOGIN" then
        -- ensure defaults applied and set initial visibility
        for k, v in pairs(defaults) do
            if CrosshairsDB[k] == nil then CrosshairsDB[k] = v end
        end
        BuildCircleLines()
        ApplyCombatState()
    else
        ApplyCombatState()
    end
end)

-- Slash command for simple configuration
SLASH_CROSSHAIRS1 = "/crosshairs"
SLASH_CROSSHAIRS2 = "/ch"
SlashCmdList["CROSSHAIRS"] = function(msg)
    msg = (msg or ""):lower()
    local args = {}
    for word in string.gmatch(msg, "%S+") do table.insert(args, word) end

    local function usage()
        print("crosshairs commands:")
        print("/crosshairs status - show current settings")
        print("/crosshairs set <cross|circle> <in|out> <on|off> - set visibility in/out of combat")
        print("/crosshairs set segments <n> - set circle segment count (more => smoother)")
        print("/crosshairs set thickness <n> - set segment thickness (px)")
        print("/crosshairs set radius <n> - set base radius (px)")
        print("/crosshairs set crosssize <n> - set cross leg length (px)")
        print("/crosshairs set crossthickness <n> - set cross thickness (px)")
        print("/crosshairs off - hide both the cross and circle until re-enabled")
        print("/crosshairs on - restore visibility based on current settings")
        print("Examples: /crosshairs set cross in on, /crosshairs off, /crosshairs set segments 128")
    end

    if #args == 0 then
        usage()
        return
    end

    if args[1] == "status" then
        print("force off:", tostring(CrosshairsDB.forceOff))
        print("cross in combat:", tostring(CrosshairsDB.crossInCombat))
        print("cross out of combat:", tostring(CrosshairsDB.crossOutOfCombat))
        print("circle in combat:", tostring(CrosshairsDB.circleInCombat))
        print("circle out of combat:", tostring(CrosshairsDB.circleOutOfCombat))
        print("circle segments:", tostring(CrosshairsDB.circleSegments))
        print("circle thickness:", tostring(CrosshairsDB.circleLineThickness))
        print("circle base radius:", tostring(CrosshairsDB.circleBaseRadius))
        print("cross size:", tostring(CrosshairsDB.crossSize))
        print("cross thickness:", tostring(CrosshairsDB.crossThickness))
        return
    end

    if args[1] == "set" and args[2] and args[3] and args[4] then
        local what = args[2]
        local when = args[3]
        local val = args[4]
        local bool = (val == "on" or val == "true")
        if what == "cross" then
            if when == "in" then CrosshairsDB.crossInCombat = bool
            elseif when == "out" then CrosshairsDB.crossOutOfCombat = bool
            else print("unknown option: "..when); return end
        elseif what == "circle" then
            if when == "in" then CrosshairsDB.circleInCombat = bool
            elseif when == "out" then CrosshairsDB.circleOutOfCombat = bool
            else print("unknown option: "..when); return end
        else
            print("unknown setting: "..what)
            return
        end
        ApplyCombatState()
        print("Setting applied.")
        return
    end

    -- extended set commands for visual parameters
    if args[1] == "set" and args[2] == "segments" and tonumber(args[3]) then
        CrosshairsDB.circleSegments = math.max(3, tonumber(args[3]))
        BuildCircleLines()
        print("Crosshairs: circleSegments set to", CrosshairsDB.circleSegments)
        return
    end

    if args[1] == "set" and args[2] == "thickness" and tonumber(args[3]) then
        CrosshairsDB.circleLineThickness = math.max(1, tonumber(args[3]))
        BuildCircleLines()
        print("Crosshairs: circleLineThickness set to", CrosshairsDB.circleLineThickness)
        return
    end

    if args[1] == "set" and args[2] == "radius" and tonumber(args[3]) then
        CrosshairsDB.circleBaseRadius = math.max(4, tonumber(args[3]))
        print("Crosshairs: circleBaseRadius set to", CrosshairsDB.circleBaseRadius)
        return
    end

    if args[1] == "set" and args[2] == "crosssize" and tonumber(args[3]) then
        CrosshairsDB.crossSize = math.max(4, tonumber(args[3]))
        ApplyCrossSettings()
        print("Crosshairs: crossSize set to", CrosshairsDB.crossSize)
        return
    end

    if args[1] == "set" and args[2] == "crossthickness" and tonumber(args[3]) then
        CrosshairsDB.crossThickness = math.max(1, tonumber(args[3]))
        ApplyCrossSettings()
        print("Crosshairs: crossThickness set to", CrosshairsDB.crossThickness)
        return
    end

    usage()
end

-- Options panel: Interface/Options/AddOns -> Crosshairs
do
    local panel = CreateFrame("Frame")
    panel.name = "Crosshairs"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Crosshairs")

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

    local function AddSlider(label, dbKey, minV, maxV, step, onChange)
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
        slider:SetScript("OnValueChanged", function(self, value)
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
    AddCheckbox("Show in combat", "Show the center cross while in combat.", "crossInCombat", ApplyCombatState)
    AddCheckbox("Show out of combat", "Show the center cross while out of combat.", "crossOutOfCombat", ApplyCombatState)
    AddSlider("Cross size", "crossSize", 4, 200, 1, ApplyCrossSettings)
    AddSlider("Cross thickness", "crossThickness", 1, 30, 1, ApplyCrossSettings)

    AddHeading("Cursor Circle")
    AddCheckbox("Show in combat", "Show the cursor circle while in combat.", "circleInCombat", ApplyCombatState)
    AddCheckbox("Show out of combat", "Show the cursor circle while out of combat.", "circleOutOfCombat", ApplyCombatState)
    AddSlider("Base radius", "circleBaseRadius", 4, 150, 1, nil)
    AddSlider("Segments", "circleSegments", 8, 720, 1, BuildCircleLines)
    AddSlider("Line thickness", "circleLineThickness", 1, 20, 1, BuildCircleLines)

    AddHeading("Other")
    AddCheckbox("Debug mode", "Show a cursor-tracking debug dot and print detailed diagnostic messages.", "debugMode", function()
        if debugDot then
            if CrosshairsDB.debugMode then debugDot:Show() else debugDot:Hide() end
        end
    end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -8, -24)
    resetButton:SetSize(140, 22)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        for k, v in pairs(defaults) do CrosshairsDB[k] = v end
        for _, refresh in ipairs(widgets) do refresh() end
        BuildCircleLines()
        ApplyCrossSettings()
        ApplyCombatState()
        print("Crosshairs: settings reset to defaults")
    end)

    function panel.RefreshWidgets()
        for _, refresh in ipairs(widgets) do refresh() end
    end
    panel:SetScript("OnShow", panel.RefreshWidgets)

    optionsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        optionsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end


-- Add '/crosshairs options' shortcut by wrapping existing command handler
local oldCrossFn = SlashCmdList["CROSSHAIRS"]
local testCircleFrame
local testActive = false
local diagFrame
local circTestActive = false
local function BuildTestCircle()
    if not testCircleFrame then
        testCircleFrame = CreateFrame("Frame", "CrosshairsTestCircle", UIParent)
        testCircleFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        testCircleFrame:SetFrameStrata("HIGH")
        testCircleFrame:SetSize(100, 100)
        testCircleFrame:Show()
    end
    -- Build lines on test frame
    testCircleFrame.lines = testCircleFrame.lines or {}
    local n = math.max(3, tonumber(CrosshairsDB.circleSegments or defaults.circleSegments))
    local thickness = tonumber(CrosshairsDB.circleLineThickness or defaults.circleLineThickness)
    for i = 1, n do
        if not testCircleFrame.lines[i] then
            testCircleFrame.lines[i] = testCircleFrame:CreateLine()
            testCircleFrame.lines[i]:SetColorTexture(0.8, 0.2, 0.2, 1)
        end
        testCircleFrame.lines[i]:SetThickness(thickness)
        testCircleFrame.lines[i]:Show()
    end
    for i = n+1, #(testCircleFrame.lines) do
        if testCircleFrame.lines[i] then testCircleFrame.lines[i]:Hide() end
    end
    -- use same scaling as real circle so tests match appearance
    local r = (CrosshairsDB.circleBaseRadius or defaults.circleBaseRadius) * circleScale
    local pts = {}
    for i = 1, n do
        local angle = (i - 1) * (2 * math.pi / n)
        pts[i] = { x = math.cos(angle) * r, y = math.sin(angle) * r }
    end
    for i = 1, n do
        local nexti = (i % n) + 1
        testCircleFrame.lines[i]:SetStartPoint("CENTER", testCircleFrame, "CENTER", pts[i].x, pts[i].y)
        testCircleFrame.lines[i]:SetEndPoint("CENTER", testCircleFrame, "CENTER", pts[nexti].x, pts[nexti].y)
    end
end

SlashCmdList["CROSSHAIRS"] = function(msg)
    local m = (msg or ""):lower()
    if m == "options" or m == "config" or m == "gui" then
        if Settings and Settings.OpenToCategory and optionsCategoryID then
            -- Blizzard's API sometimes needs to be called twice to focus correctly on first open
            Settings.OpenToCategory(optionsCategoryID)
            Settings.OpenToCategory(optionsCategoryID)
        elseif InterfaceOptionsFrame_OpenToCategory and optionsPanel then
            InterfaceOptionsFrame_OpenToCategory(optionsPanel)
            InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        end
        print("Crosshairs: opened the options panel (Game Menu > Options > AddOns > Crosshairs). Slash commands (alias: /ch):")
        print("/crosshairs status - show current settings")
        print("/crosshairs set <cross|circle> <in|out> <on|off> - set visibility")
        print("/crosshairs set segments <n> - set circle segment count (more => smoother)")
        print("/crosshairs set thickness <n> - set circle segment thickness (px)")
        print("/crosshairs set radius <n> - set circle base radius (px)")
        print("/crosshairs set crosssize <n> - set cross leg length (px)")
        print("/crosshairs set crossthickness <n> - set cross thickness (px)")
        print("/crosshairs off - hide both the cross and circle until re-enabled")
        print("/crosshairs on - restore visibility based on current settings")
        print("/crosshairs circletest - show test circle at screen center")
        print("/crosshairs test - segment test circle")
        print("/crosshairs diag - diagnostic overlay (lines + dots)")
        print("/crosshairs debug on|off - show/hide cursor debug dot (enables detailed logs)")
        return
    end

    if m == "off" then
        CrosshairsDB.forceOff = true
        if frame then frame:Hide() end
        if circleFrame then circleFrame:Hide() end
        print("Crosshairs: all crosshair elements turned off")
        return
    end

    if m == "on" then
        CrosshairsDB.forceOff = nil
        ApplyCombatState()
        print("Crosshairs: crosshair visibility restored")
        return
    end

    if m == "test" then
        testActive = not testActive
        if testActive then
            BuildTestCircle()
            print("Crosshairs: test circle shown at screen center")
        else
            if testCircleFrame then testCircleFrame:Hide() end
            print("Crosshairs: test circle hidden")
        end
        return
    end

    if m == "diag" then
        -- diagnostic: show both line and dot circle at center so you can see which renders
        if not diagFrame then
            diagFrame = CreateFrame("Frame", "CrosshairsDiagFrame", UIParent)
            diagFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            diagFrame:SetSize(200, 200)
            diagFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            diagFrame.lines = {}
            diagFrame.dots = {}
            local n = math.max(6, tonumber(CrosshairsDB.circleSegments or defaults.circleSegments))
            for i = 1, n do
                local l = diagFrame:CreateLine()
                l:SetColorTexture(1, 0, 0, 1)
                l:SetThickness(3)
                diagFrame.lines[i] = l
                local t = diagFrame:CreateTexture(nil, "OVERLAY")
                t:SetColorTexture(0, 0.8, 1, 1)
                t:SetSize(3, 3)
                diagFrame.dots[i] = t
            end
            -- use same scaling as normal circle
            local r = (CrosshairsDB.circleBaseRadius or defaults.circleBaseRadius) * circleScale
            local pts = {}
            for i = 1, n do
                local angle = (i - 1) * (2 * math.pi / n)
                pts[i] = { x = math.cos(angle) * r, y = math.sin(angle) * r }
            end
            for i = 1, n do
                local nexti = (i % n) + 1
                diagFrame.lines[i]:SetStartPoint("CENTER", diagFrame, "CENTER", pts[i].x, pts[i].y)
                diagFrame.lines[i]:SetEndPoint("CENTER", diagFrame, "CENTER", pts[nexti].x, pts[nexti].y)
                diagFrame.dots[i]:SetPoint("CENTER", diagFrame, "CENTER", pts[i].x, pts[i].y)
            end
        else
            if diagFrame:IsShown() then diagFrame:Hide(); print("Crosshairs: diagnostic frame hidden") else diagFrame:Show(); print("Crosshairs: diagnostic frame shown") end
        end
        return
    end

    if m == "circletest" then
        -- show circleFrame at screen center with background so we can see bounding box
        if not circTestActive then
            circTestActive = true
            BuildCircleLines()
            -- respect the same scale used during normal cursor drawing
            local r = (CrosshairsDB.circleBaseRadius or defaults.circleBaseRadius) * circleScale
            local size = math.ceil(r * 2 + 8)
            circleFrame:SetSize(size, size)
            circleFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            if not circleFrame.bg then
                circleFrame.bg = circleFrame:CreateTexture(nil, "BACKGROUND")
                circleFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.2)
                circleFrame.bg:SetAllPoints(true)
            end
            circleFrame.bg:Show()
            -- ensure textures are rebuilt and visible
            BuildCircleLines()
            updateCirclePositions(r)
            -- make textures bigger and brighter for debugging
            for i = 1, #circleTextures do
                circleTextures[i]:SetColorTexture(1, 1, 0, 1)
                circleTextures[i]:SetSize(6, 6)
                circleTextures[i]:Show()
            end
            if circleFrame.bg.SetDrawLayer then circleFrame.bg:SetDrawLayer("BACKGROUND", -1) end
            if CrosshairsDB.debugMode then print("Crosshairs: circletest circleTextures count", #circleTextures) end
            circleFrame._forceVisible = true
            circleFrame:Show()
            if CrosshairsDB.debugMode then print("Crosshairs: circletest shown at center, size", size) end
        else
            circTestActive = false
            if circleFrame.bg then circleFrame.bg:Hide() end
            circleFrame._forceVisible = nil
            circleFrame:Hide()
            print("Crosshairs: circletest hidden")
        end
        return
    end

    if m:match("^debug%s+(on|off)$") then
        local mode = m:match("^debug%s+(on|off)$")
        CrosshairsDB.debugMode = (mode == "on")
        if CrosshairsDB.debugMode and debugDot then debugDot:Show() end
        if not CrosshairsDB.debugMode and debugDot then debugDot:Hide() end
        print("Crosshairs: debug mode set to", mode)
        return
    end

    oldCrossFn(msg)
end

-- Try to build circle lines now to ensure they exist (safe call)
local ok, err = pcall(BuildCircleLines)
if ok then if CrosshairsDB.debugMode then print("Crosshairs: initial BuildCircleLines succeeded") end else print("Crosshairs: initial BuildCircleLines failed:", err) end

-- Apply cross settings immediately so the cross uses stored values on load
pcall(ApplyCrossSettings)

