std = "lua51"
max_line_length = false

-- SavedVariables global declared in the .toc, plus the slash-command globals
-- this addon defines and writes into (SLASH_* and SlashCmdList's field).
globals = {
    "CrosshairsDB",
    "SLASH_CROSSHAIRS1", "SLASH_CROSSHAIRS2",
    "SlashCmdList",
}

-- WoW API globals used by this addon.
read_globals = {
    "CreateFrame", "UIParent", "GetCursorPosition", "GetTime", "IsAltKeyDown",
    "InCombatLockdown", "UnitCastingInfo", "UnitChannelInfo", "GetSpellCooldown",
    "C_Timer", "debugstack", "Settings", "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory",
}

ignore = {
    "212", -- unused argument: WoW event/widget callback signatures are fixed by the API
}
