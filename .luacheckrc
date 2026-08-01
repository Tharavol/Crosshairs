std = "lua51"
max_line_length = 120

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
    "C_AddOns",

    -- Frame / UI globals
    "CreateFrame", "UIParent", "GetCursorPosition",

    -- Settings API (Settings is retail; the InterfaceOptions_* pair is the
    -- pre-10.0 fallback the addon still branches on)
    "Settings", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",

    -- Player / spell state
    "GetAddOnMetadata", "GetSpellCooldown", "GetTime", "InCombatLockdown",
    "IsAltKeyDown", "UnitCastingInfo", "UnitChannelInfo",
}
