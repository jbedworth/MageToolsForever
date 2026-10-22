local addonName, MTF = ...

local DEFAULT_TITLE = "Mage Tools Forever"
local READY_MESSAGE = "  Ready. Type /mtf to open the settings."
local SLASH_KEY = "MAGETOOLSFOREVER"
local PRIMARY_SLASH = "/mtf"
local BACKUP_SLASH = "/magetools"
local MAX_SLASH_ALIASES = 10
MTF.available = false

function MTF.Report(message)
    DEFAULT_CHAT_FRAME:AddMessage("MTF: " .. tostring(message))
end

-- Combat data can be a secret value on the target client: code may store and
-- pass it on, but never compare, concatenate, or print it.
function MTF.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- Text for diagnostics that never touches a secret value's contents.
function MTF.Describe(value)
    if MTF.IsSecret(value) then
        return "secret"
    end
    return tostring(value)
end

-- Reads TOC fields so the banner follows the packaged version; never gates operations.
local function Metadata(field)
    if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
        return nil
    end
    local value = C_AddOns.GetAddOnMetadata(addonName, field)
    if type(value) == "string" and value:find("%S") then
        return value
    end
end

local function ReportLoaded(available)
    local banner = Metadata("Title") or DEFAULT_TITLE
    local version, author = Metadata("Version"), Metadata("Author")
    if version then
        banner = banner .. " " .. version
    end
    if author then
        banner = banner .. " by " .. author
    end
    MTF.Report(banner)
    if available then
        MTF.Report(READY_MESSAGE)
    end
end

-- Functions other runtime files must define. A mixed install of old and new
-- files otherwise fails silently, because the client hides Lua errors by default.
local REQUIRED_NAMESPACE = {
    "ParseCommand", "HandleCommand",
    "CheckConjureCapabilities", "InitializeConjure", "RefreshConjure",
    "ApplyConjureMacros", "ReportConjureStatus", "ReportConjureDebug", "ReportClickDebug",
    "CharacterMacrosAvailable", "WriteCharacterMacro", "DeleteCharacterMacro", "ApplyPolymorphMacro",
    "AddInputHandler", "RunOnNextInput",
    "InitializePortals", "RefreshPortals", "ReportPortalsDebug",
    "InitializePolymorph", "RefreshPolymorph", "ReportPolymorphDebug",
    "InitializeOptions", "OpenSettings",
}

local function CheckInstalledFiles()
    for _, name in ipairs(REQUIRED_NAMESPACE) do
        if type(MTF[name]) ~= "function" then
            return false, "AddOn files are from different versions (missing " .. name
                .. "). Reinstall every Mage Tools Forever file, then restart the client."
        end
    end
    return true
end

local function CheckClass()
    local _, classFile = UnitClass("player")
    if classFile ~= "MAGE" then
        return false, "Mage Tools Forever is for Mages, so it stays off on this character."
    end
    return true
end

-- Per-character settings in MageToolsForeverDB, repaired on load so a damaged
-- or older table can never break the AddOn.

-- How much food or water one trade gives (author-approved): 10 by default,
-- enough to get a group going quickly.
MTF.SHARE_SIZE_MIN = 1
MTF.SHARE_SIZE_MAX = 20
MTF.DEFAULT_SHARE_SIZE = 10

-- Frame sizes in percent (author-approved).
MTF.SCALE_MIN = 50
MTF.SCALE_MAX = 150
MTF.SCALE_STEP = 5
MTF.DEFAULT_SCALE = 100

-- The Polymorph bar's own sizes and opacity (author-approved, 1.1.0, after
-- WTF's DoT tracker): the defaults draw the bar as it always looked. "Bar
-- size" above stays a scale on top of them.
MTF.POLYMORPH_SIZE_SPECS = {
    {key = "width", label = "Bar width", min = 120, max = 400, step = 10, default = 200},
    {key = "height", label = "Bar height", min = 10, max = 40, step = 1, default = 16},
    {key = "textScale", label = "Text size", min = 50, max = 200, step = 5, default = 100, percent = true},
}
MTF.POLYMORPH_OPACITY_MIN = 10
MTF.POLYMORPH_OPACITY_MAX = 100
MTF.POLYMORPH_OPACITY_STEP = 5
MTF.DEFAULT_POLYMORPH_OPACITY = 100

-- Messages (Announce), each with its own switch and editable text
-- (author-approved). Trade whispers: %C the count, %I the item (for Food &
-- Water, the whole list: "10 Conjured Fresh Water and 10 Conjured Bread"), %T
-- the player's full name. The portal group message and the teleport emote: %D
-- the city; in the emote, %Z your zone as it is sent and %T your name. Emotes
-- start with your name.
-- The Polymorph group message: %T the mob. The defaults credit MTF, as WTF's
-- do, except the Polymorph line, the author's own classic.
MTF.ANNOUNCE_MAX_LENGTH = 255
MTF.ANNOUNCE_DEFAULTS = {
    waterWhisperText = "Here's %C %I, conjured from pure arcane energy. Drink up, %T! Courtesy of Mage Tools Forever (MTF)",
    foodWhisperText = "Here's %C %I, conjured from thin air: no crumbs, no calories. Courtesy of Mage Tools Forever (MTF)",
    bothWhisperText = "Here's %I, conjured from pure arcane energy. Eat, drink, and be merry, %T! Courtesy of Mage Tools Forever (MTF)",
    portalGroupText = "A portal to %D shimmers open! Step through before it fades. - via Mage Tools Forever (MTF)",
    polymorphGroupText = "Sheeping %T; you spank it, you tank it",
    teleportEmoteText = "summons powerful arcane energies to whisk themselves away to %Z. - via Mage Tools Forever (MTF)",
}
local ANNOUNCE_SWITCHES = {"waterWhisper", "foodWhisper", "bothWhisper", "portalGroup", "teleportEmote",
    "polymorphGroup"}

-- A message text: a non-empty single line within the chat limit, else the default.
function MTF.SanitizeAnnouncement(text, default)
    if type(text) ~= "string" then
        return default
    end
    text = text:match("^%s*(.-)%s*$")
    if text == "" or #text > MTF.ANNOUNCE_MAX_LENGTH or text:find("[\r\n]") then
        return default
    end
    return text
end

-- Replaces %X tokens with values, {T = "Lowbie Smith", D = "Ironforge"}.
function MTF.FormatAnnouncement(text, values)
    return (text:gsub("%%(%a)", function(token)
        local value = values[token]
        if value == nil then
            return "%" .. token
        end
        return tostring(value)
    end))
end

function MTF.FormatShareWhisper(text, count, item, target)
    return MTF.FormatAnnouncement(text, {C = count, I = item, T = target or "friend"})
end

-- Dyre's Shields Up draws the shield display and Dyre's Buff Reminders shows
-- the buff reminders and plays the cooldown chimes, for every class (author,
-- 1.2.0: MTF depends on them, so players get them on their other classes too;
-- CurseForge installs them with MTF). The TOC lists them as OptionalDeps, so
-- MTF loads without them and says once per session what to install or enable.
MTF.COMPANIONS = {
    {addon = "DyresShieldsUp", title = "Dyre's Shields Up", what = "the shield display"},
    {addon = "DyresBuffReminders", title = "Dyre's Buff Reminders", what = "buff reminders and cooldown chimes"},
}

function MTF.CompanionLoaded(addon)
    if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
        return false
    end
    return C_AddOns.IsAddOnLoaded(addon) == true
end

-- What to tell a player who lacks a companion: install it, or enable it when
-- the AddOn list has it (GetAddOnInfo's reason is "MISSING" when it is not
-- installed). Only CurseForge is named as the place to get it.
function MTF.CompanionMessage(companion)
    local reason
    if type(C_AddOns) == "table" and type(C_AddOns.GetAddOnInfo) == "function" then
        local _, _, _, _, why = C_AddOns.GetAddOnInfo(companion.addon)
        reason = why
    end
    if reason ~= nil and reason ~= "MISSING" then
        return "Enable " .. companion.title .. " in the AddOn list for " .. companion.what .. "."
    end
    return "Install " .. companion.title .. " from CurseForge for " .. companion.what .. "."
end

local function ReportMissingCompanions()
    for _, companion in ipairs(MTF.COMPANIONS) do
        if not MTF.CompanionLoaded(companion.addon) then
            MTF.Report(MTF.CompanionMessage(companion))
        end
    end
end

local function IsWholeNumber(value)
    return type(value) == "number" and value == math.floor(value)
end

function MTF.SanitizeShareSize(value)
    if not IsWholeNumber(value) then
        return MTF.DEFAULT_SHARE_SIZE
    end
    return math.max(MTF.SHARE_SIZE_MIN, math.min(MTF.SHARE_SIZE_MAX, value))
end

function MTF.SanitizeScale(value)
    if not IsWholeNumber(value) then
        return MTF.DEFAULT_SCALE
    end
    local stepped = math.floor(value / MTF.SCALE_STEP + 0.5) * MTF.SCALE_STEP
    return math.max(MTF.SCALE_MIN, math.min(MTF.SCALE_MAX, stepped))
end

-- A whole number on the slider's steps, within its range, else the default.
function MTF.SanitizeStepped(value, minValue, maxValue, step, default)
    if not IsWholeNumber(value) then
        return default
    end
    local stepped = minValue + math.floor((value - minValue) / step + 0.5) * step
    return math.max(minValue, math.min(maxValue, stepped))
end

function MTF.SanitizePolymorphSize(spec, value)
    return MTF.SanitizeStepped(value, spec.min, spec.max, spec.step, spec.default)
end

function MTF.SanitizePolymorphOpacity(value)
    return MTF.SanitizeStepped(value, MTF.POLYMORPH_OPACITY_MIN, MTF.POLYMORPH_OPACITY_MAX,
        MTF.POLYMORPH_OPACITY_STEP, MTF.DEFAULT_POLYMORPH_OPACITY)
end

local function SanitizePosition(position)
    if type(position) ~= "table" or type(position.point) ~= "string"
        or type(position.relativePoint) ~= "string"
        or type(position.x) ~= "number" or type(position.y) ~= "number" then
        return nil
    end
    return {point = position.point, relativePoint = position.relativePoint,
        x = position.x, y = position.y}
end

function MTF.SanitizeDB(db)
    if type(db) ~= "table" then
        db = {}
    end
    local conjure = type(db.conjure) == "table" and db.conjure or {}
    db.conjure = {
        enabled = conjure.enabled ~= false,
        position = SanitizePosition(conjure.position),
        macros = conjure.macros ~= false,
        shareSize = MTF.SanitizeShareSize(conjure.shareSize),
        scale = MTF.SanitizeScale(conjure.scale),
    }
    local portals = type(db.portals) == "table" and db.portals or {}
    db.portals = {
        enabled = portals.enabled ~= false,
        position = SanitizePosition(portals.position),
        scale = MTF.SanitizeScale(portals.scale),
    }
    local polymorph = type(db.polymorph) == "table" and db.polymorph or {}
    db.polymorph = {
        enabled = polymorph.enabled ~= false,
        position = SanitizePosition(polymorph.position),
        scale = MTF.SanitizeScale(polymorph.scale),
        mark = polymorph.mark ~= false,
        macro = polymorph.macro ~= false,
        opacity = MTF.SanitizePolymorphOpacity(polymorph.opacity),
    }
    for _, spec in ipairs(MTF.POLYMORPH_SIZE_SPECS) do
        db.polymorph[spec.key] = MTF.SanitizePolymorphSize(spec, polymorph[spec.key])
    end
    local announce = type(db.announce) == "table" and db.announce or {}
    -- Trade whispers once had one switch on the Conjure page.
    local formerWhisper = conjure.whisper
    db.announce = {}
    for _, key in ipairs(ANNOUNCE_SWITCHES) do
        if type(announce[key]) == "boolean" then
            db.announce[key] = announce[key]
        elseif key:find("Whisper$") and type(formerWhisper) == "boolean" then
            db.announce[key] = formerWhisper
        else
            db.announce[key] = true
        end
    end
    for key, default in pairs(MTF.ANNOUNCE_DEFAULTS) do
        db.announce[key] = MTF.SanitizeAnnouncement(announce[key], default)
    end
    -- The lock is Dyre's Toolkit's (one for every Dyre's AddOn); MTF keeps a
    -- copy for its modules.
    db.locked = db.locked ~= false
    -- db.shield, db.reminders, and db.chimes (MTF 1.1 and older) stay exactly
    -- as they are: Dyre's Shields Up and Dyre's Buff Reminders copy them once
    -- per character, also when installed later.
    return db
end

-- Another AddOn can register the same slash command; the last one loaded wins.
-- Returns the other command key, or nil when /mtf is ours alone.
local function FindSlashConflict()
    for key in pairs(SlashCmdList) do
        if key ~= SLASH_KEY then
            for index = 1, MAX_SLASH_ALIASES do
                local alias = _G["SLASH_" .. key .. index]
                if type(alias) == "string" and alias:lower() == PRIMARY_SLASH then
                    return key
                end
            end
        end
    end
end

-- Hardware input. The client lets AddOns move items only during a key press
-- or click, so a refused trade placement waits for the next one. Core hooks
-- every key press and every click on the game world, as RestedXP does; the
-- keyboard frame passes every key on to the game and is enabled only after the
-- client confirms that.
local inputHandlers, nextInput = {}, {}

function MTF.AddInputHandler(handler)
    inputHandlers[#inputHandlers + 1] = handler
end

-- Runs once, at the next key press or click.
function MTF.RunOnNextInput(action)
    nextInput[#nextInput + 1] = action
end

local function OnInput()
    for _, handler in ipairs(inputHandlers) do
        handler()
    end
    if #nextInput > 0 then
        local actions = nextInput
        nextInput = {}
        for _, action in ipairs(actions) do
            action()
        end
    end
end

local function InstallInputHooks()
    local keys = CreateFrame("Frame", nil, UIParent)
    if type(keys.SetPropagateKeyboardInput) == "function"
        and type(keys.GetPropagateKeyboardInput) == "function" then
        keys:SetPropagateKeyboardInput(true)
        if keys:GetPropagateKeyboardInput() then
            keys:SetScript("OnKeyDown", OnInput)
            keys:EnableKeyboard(true)
        end
    end
    WorldFrame:HookScript("OnMouseDown", OnInput)
end

-- Dyre's Toolkit (required, contract 2; author-approved 2026-10-20: "all the
-- widget layout ... centralized in Dyre's Tools"). Every movable MTF frame is
-- a toolkit widget: the toolkit places, drags, snaps, resizes from the
-- center, outlines, saves, and resets it, and draws the grid and the size
-- sliders. MTF only fills the widgets with its content. Without contract 2
-- (no toolkit, or an older one) MTF stays off and says what to install.
local TOOLKIT_CONTRACT = 2
local TOOLKIT_FUNCTIONS = {
    "RegisterAddOn", "RegisterSettingsCategory", "IsLocked", "SetLocked", "OpenSettings", "CreateWidget",
    "AddWidgetSettings", "ResetWidgets", "AddSettingsLink",
}
local TOOLKIT_MISSING = "Mage Tools Forever needs Dyre's Toolkit 2.0 or later: install or update it from "
    .. "CurseForge. MTF stays off until then."

-- Dyre's Toolkit with the contract and functions MTF uses, else nil.
function MTF.Toolkit()
    local toolkit = rawget(_G, "DyresToolkit")
    if type(toolkit) ~= "table" or type(toolkit.RequireContract) ~= "function" then
        return nil
    end
    toolkit = toolkit.RequireContract(TOOLKIT_CONTRACT)
    if type(toolkit) ~= "table" then
        return nil
    end
    for _, name in ipairs(TOOLKIT_FUNCTIONS) do
        if type(toolkit[name]) ~= "function" then
            return nil
        end
    end
    return toolkit
end

-- The toolkit's lock changed: MTF's samples (the Polymorph sample, the portal
-- bar with nothing known) show or hide, quietly; the toolkit says one line for
-- all and draws the outlines.
local function ApplyFramesLocked(locked)
    MTF.db.locked = locked
    MTF.RefreshConjure()
    MTF.RefreshPortals()
    MTF.RefreshPolymorph()
end

-- /mtf unlock and /mtf lock: one layout mode for every Dyre's AddOn.
function MTF.SetFramesLocked(locked)
    MTF.toolkit.SetLocked(locked)
end

function MTF.Unlock()
    MTF.SetFramesLocked(false)
end

function MTF.Lock()
    MTF.SetFramesLocked(true)
end

-- /mtf reset: every MTF widget back to its default place (the toolkit waits
-- out combat for those holding secure buttons).
function MTF.ResetPositions()
    MTF.toolkit.ResetWidgets(addonName)
    if InCombatLockdown() then
        MTF.Report("MTF frames move back to their default places after combat.")
    end
end

-- After the modules start, so the toolkit can show their frames at once.
local function RegisterWithToolkit()
    MTF.toolkit.RegisterAddOn({
        addon = addonName,
        title = DEFAULT_TITLE,
        setLocked = function(locked) ApplyFramesLocked(locked == true) end,
        openSettings = function() MTF.OpenSettings() end,
    })
end

SLASH_MAGETOOLSFOREVER1 = PRIMARY_SLASH
SLASH_MAGETOOLSFOREVER2 = BACKUP_SLASH
SlashCmdList[SLASH_KEY] = MTF.HandleCommand

local function LoadDB()
    MageToolsForeverDB = MTF.SanitizeDB(MageToolsForeverDB)
    MTF.db = MageToolsForeverDB
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            LoadDB()
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    if not MTF.db then
        LoadDB()
    end
    local available, message = CheckInstalledFiles()
    if available then
        available, message = CheckClass()
    end
    if available then
        MTF.toolkit = MTF.Toolkit()
        available = MTF.toolkit ~= nil
        message = TOOLKIT_MISSING
    end
    if available then
        available, message = MTF.CheckConjureCapabilities()
        if not available then
            message = "This client lacks " .. message .. ", so Mage Tools Forever stays off."
        end
    end
    MTF.available = available
    ReportLoaded(available)
    local conflict = FindSlashConflict()
    if conflict then
        MTF.Report("Another AddOn (" .. conflict .. ") also uses " .. PRIMARY_SLASH
            .. ". Use " .. BACKUP_SLASH .. " instead.")
    end
    if not available then
        MTF.Report(message)
        return
    end
    -- Called directly rather than from each file's own PLAYER_LOGIN handler,
    -- so startup never depends on event handler order.
    InstallInputHooks()
    MTF.db.locked = MTF.toolkit.IsLocked() ~= false
    MTF.InitializeConjure()
    MTF.InitializePortals()
    MTF.InitializePolymorph()
    MTF.InitializeOptions()
    RegisterWithToolkit()
    ReportMissingCompanions()
end)
