local _, MTF = ...

local USAGE = "Use /mtf, /mtf options, /mtf conjure, /mtf unlock, /mtf lock, /mtf reset, /mtf debug_conjure, /mtf debug_shield, "
    .. "/mtf debug_chimes, /mtf debug_portals, /mtf debug_polymorph, "
    .. "/mtf debug_reminders, or /mtf debug_click."
local UNAVAILABLE = "Mage Tools Forever is unavailable. Check the MTF login message."

-- Each command is one word; "" opens the settings. Handlers live in the other
-- files. Diagnostics also run when MTF is unavailable, to help explain why.
local COMMANDS = {
    [""] = {handler = "OpenSettings"},
    options = {handler = "OpenSettings"},
    conjure = {handler = "ReportConjureStatus"},
    reset = {handler = "ResetPositions"},
    unlock = {handler = "Unlock"},
    lock = {handler = "Lock"},
    debug_conjure = {handler = "ReportConjureDebug", always = true},
    debug_shield = {handler = "ReportShieldDebug", always = true},
    debug_chimes = {handler = "ReportChimesDebug", always = true},
    debug_portals = {handler = "ReportPortalsDebug"},
    debug_polymorph = {handler = "ReportPolymorphDebug"},
    debug_reminders = {handler = "ReportRemindersDebug"},
    debug_click = {handler = "ReportClickDebug"},
}

function MTF.ParseCommand(message)
    if type(message) ~= "string" then
        return nil, USAGE
    end
    local command = message:match("^%s*(.-)%s*$"):lower()
    if command:find("%s") or not COMMANDS[command] then
        return nil, USAGE
    end
    return command
end

function MTF.HandleCommand(message)
    local command, usage = MTF.ParseCommand(message)
    if not command then
        MTF.Report(usage)
        return
    end
    local entry = COMMANDS[command]
    if not MTF.available and not entry.always then
        MTF.Report(UNAVAILABLE)
        return
    end
    MTF[entry.handler]()
end
