std = "lua51"
max_line_length = 120

-- The luarocks CI action installs into .luarocks/ inside the workspace, so
-- `luacheck .` would otherwise lint the toolchain along with the addon.
exclude_files = {".luarocks/**", ".luarocks", "lua_modules/**"}

-- WoW event handlers always receive (self, event, ...); ignore unused args
-- entirely since callbacks must match Blizzard's fixed signatures.
ignore = {
    "212", -- unused argument
}

globals = {
    -- SavedVariables declared in the .toc
    "CrosshairsDB",

    "SLASH_CROSSHAIRS1",
    "SLASH_CROSSHAIRS2",
    "SlashCmdList",
}

read_globals = {
    -- Namespaced API tables
    "C_AddOns", "C_Spell",

    -- Frame / UI globals
    "CreateFrame", "UIParent", "GetCursorPosition",

    -- Settings API (Settings is retail; the InterfaceOptions_* pair is the
    -- pre-10.0 fallback the addon still branches on)
    "Settings", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",

    -- Player / spell state
    "GetAddOnMetadata", "GetSpellCooldown", "GetTime", "InCombatLockdown",
    "IsAltKeyDown", "UnitCastingInfo", "UnitChannelInfo",
}
