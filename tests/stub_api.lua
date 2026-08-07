-- stub_api.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- Stubs the slice of the WoW API this addon actually touches, then loads the addon's
-- Lua files (in the order Crosshairs.toc lists them) into a fresh, isolated environment
-- per call so tests don't leak state into one another.
--
-- Usage: local stub = dofile("tests/stub_api.lua")

local M = {}

-- A frame/texture/fontstring/slider/checkbutton stand-in. Real widgets are split across
-- many userdata types with different method sets; the addon only ever calls a small,
-- fixed set of methods on any of them, so one table with all of those methods covers
-- every kind CreateFrame/CreateTexture/CreateFontString are asked for here.
local MakeWidget
MakeWidget = function(kind, name)
    local w = { kind = kind, name = name, _children = {} }

    function w:SetPoint(...)
        self._point = { ... }
        self._setPointCalls = (self._setPointCalls or 0) + 1
    end
    function w:SetSize(width, height) self._width, self._height = width, height end
    function w:SetWidth(width) self._width = width end
    function w:SetHeight(height) self._height = height end
    function w:SetScrollChild(child) self._scrollChild = child end
    function w:SetFrameStrata(strata) self._strata = strata end
    function w:EnableMouse(enabled) self._mouseEnabled = enabled end
    function w:SetScript(scriptType, fn)
        self._scripts = self._scripts or {}
        self._scripts[scriptType] = fn
    end
    function w:GetScript(scriptType) return self._scripts and self._scripts[scriptType] end
    function w:RegisterEvent(event)
        self._events = self._events or {}
        self._events[event] = true
    end
    function w:Show() self._shown = true end
    function w:Hide() self._shown = false end
    function w:IsShown() return self._shown and true or false end
    function w:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
    function w:SetAlpha(alpha) self._alpha = alpha end
    function w:GetAlpha() return self._alpha end
    function w:SetAllPoints() end
    function w:SetDrawLayer() end
    function w:SetJustifyH() end
    function w:SetChecked(checked) self._checked = checked and true or false end
    function w:GetChecked() return self._checked end
    function w:SetMinMaxValues(lo, hi) self._min, self._max = lo, hi end
    function w:SetValueStep(step) self._step = step end
    function w:SetObeyStepOnDrag() end
    function w:SetValue(value)
        self._value = value
        if self._scripts and self._scripts.OnValueChanged then
            self._scripts.OnValueChanged(self, value)
        end
    end
    function w:GetValue() return self._value end
    function w:GetID() return self._id end
    function w:SetText(text) self._text = text end
    function w:GetText() return self._text end
    function w:CreateTexture(texName)
        local tex = MakeWidget("Texture", texName)
        tex._parent = self
        table.insert(self._children, tex)
        if texName then _G[texName] = tex end
        return tex
    end
    function w:CreateFontString(fsName)
        local fs = MakeWidget("FontString", fsName)
        fs._parent = self
        table.insert(self._children, fs)
        if fsName then _G[fsName] = fs end
        return fs
    end
    return w
end

-- Builds one fresh stub WoW API: a per-call environment table (env), a table of
-- controllable API state (api, e.g. api.combat = true), and every frame CreateFrame
-- produces (frames) -- since the addon's event frame is anonymous, tests find it by
-- which events it registered rather than by name.
local function NewEnv()
    local frames = {}

    local function CreateFrame(frameType, name, parent, template)
        local f = MakeWidget(frameType, name)
        f._parent = parent
        f.template = template
        table.insert(frames, f)
        if name then _G[name] = f end
        if frameType == "CheckButton" then
            f.Text = MakeWidget("FontString", nil)
        end
        if frameType == "Slider" then
            -- Mimics UISliderTemplateWithLabels: Low/High/Text as direct parentKey
            -- fields, present whether or not the slider has a name.
            f.Low = MakeWidget("FontString", name and (name .. "Low"))
            f.High = MakeWidget("FontString", name and (name .. "High"))
            f.Text = MakeWidget("FontString", name and (name .. "Text"))
            if name then
                _G[name .. "Low"] = f.Low
                _G[name .. "High"] = f.High
                _G[name .. "Text"] = f.Text
            end
        end
        return f
    end

    local api = {
        combat = false,
        altDown = false,
        cursor = { 100, 100 },
        casting = nil,     -- { name, startTimeMS, endTimeMS } or nil
        channeling = nil,  -- same shape as casting
        gcd = nil,         -- { startTime, duration, isEnabled } or nil
        addonVersion = "1.2.4",
        chatLog = {},
    }

    local uiParent = MakeWidget("Frame", "UIParent")
    function uiParent:GetScale() return 1 end

    local env = setmetatable({}, { __index = _G })
    env.CreateFrame = CreateFrame
    env.UIParent = uiParent
    env.GetCursorPosition = function() return api.cursor[1], api.cursor[2] end
    env.GetTime = function() return os.clock() end
    env.InCombatLockdown = function() return api.combat end
    env.IsAltKeyDown = function() return api.altDown end
    env.UnitCastingInfo = function()
        if not api.casting then return nil end
        return api.casting.name, nil, nil, api.casting.startTimeMS, api.casting.endTimeMS
    end
    env.UnitChannelInfo = function()
        if not api.channeling then return nil end
        return api.channeling.name, nil, nil, api.channeling.startTimeMS, api.channeling.endTimeMS
    end
    env.GetSpellCooldown = function()
        if not api.gcd then return 0, 0, 0 end
        return api.gcd.startTime, api.gcd.duration, api.gcd.isEnabled and 1 or 0
    end
    env.GetAddOnMetadata = function(_, field)
        if field == "Version" then return api.addonVersion end
        return nil
    end
    env.C_Spell = {
        GetSpellCooldown = function()
            if not api.gcd then return { startTime = 0, duration = 0, isEnabled = false } end
            return { startTime = api.gcd.startTime, duration = api.gcd.duration, isEnabled = api.gcd.isEnabled }
        end,
    }
    env.C_AddOns = { GetAddOnMetadata = env.GetAddOnMetadata }
    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, msg) table.insert(api.chatLog, msg) end,
    }
    env.Settings = {
        RegisterCanvasLayoutCategory = function(_, name)
            local category = { _id = name }
            function category:GetID() return self._id end
            return category
        end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function() end,
    }
    env.SlashCmdList = {}
    env.GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        Show = function() end,
        Hide = function() end,
    }
    env.GameTooltip_Hide = function() env.GameTooltip:Hide() end
    -- Records the last info table passed to SetupColorPickerAndShow so a test can call
    -- info.swatchFunc()/cancelFunc() itself to simulate a pick, and GetColorRGB() reads
    -- back whatever the test set on ColorPickerFrame first.
    env.ColorPickerFrame = {
        SetupColorPickerAndShow = function(self, info)
            self._info = info
            self._r, self._g, self._b = info.r, info.g, info.b
        end,
        GetColorRGB = function(self) return self._r, self._g, self._b end,
    }

    return env, api, frames
end

-- Every non-comment, non-directive line in the .toc is a file to load, in order --
-- the same rule scripts/validate-toc.lua uses, so the two can't drift apart.
local function TocFileList(tocPath)
    local handle = assert(io.open(tocPath, "r"), "could not open " .. tocPath)
    local contents = handle:read("*a")
    handle:close()

    local files = {}
    for rawLine in (contents .. "\n"):gmatch("([^\n]*)\n") do
        local line = rawLine:gsub("\r$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^#") then
            table.insert(files, line)
        end
    end
    return files
end

-- Loads the addon fresh: a new stub environment and a new shared `ns` table, exactly
-- like WoW handing each file the same addon table via `...`. Returns everything a test
-- needs to drive and inspect it.
function M.LoadAddon(rootDir, tocPath)
    local env, api, frames = NewEnv()
    local ns = {}
    for _, file in ipairs(TocFileList(tocPath)) do
        local chunk = assert(loadfile(rootDir .. "/" .. file))
        setfenv(chunk, env)
        chunk("Crosshairs", ns)
    end
    return { env = env, ns = ns, api = api, frames = frames }
end

-- The addon's event frame is created anonymously (`CreateFrame("Frame")`), so it can't
-- be found by name; find it by the event only it registers for instead.
function M.FindFrame(frames, event)
    for _, f in ipairs(frames) do
        if f._events and f._events[event] then return f end
    end
    return nil
end

return M
