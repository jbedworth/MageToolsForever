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

-- Dyre's Toolkit 2.14.0's "Welcome messages at login" (John, 2026-11-23:
-- "toggle off our welcome messages unless there is an error/problem").
-- Without ShowWelcome (an older Toolkit, or none), the banner shows.
local function WelcomeHidden()
    local toolkit = rawget(_G, "DyresToolkit")
    return type(toolkit) == "table" and type(toolkit.ShowWelcome) == "function"
        and toolkit.ShowWelcome() == false
end

-- The banner and the ready hint only; problems are reported by the caller.
local function ReportLoaded(available)
    if WelcomeHidden() then
        return
    end
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
    "CharacterMacrosAvailable", "WriteCharacterMacro", "DeleteCharacterMacro",
    "AddInputHandler", "RunOnNextInput",
    "InitializePortals", "RefreshPortals", "ReportPortalsDebug",
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

-- The bars' layout (MTF 1.8.0; a CurseForge player asked: "Is it possible to
-- add an option to change the portal and conjure bars from horizontal to
-- vertical?"; John, 2026-11-27: "Yes, Toolkit feature"): Dyre's Toolkit
-- 2.18.0's button bars place the buttons as a row or a column and save the
-- choice as the widget store's `orientation`. With an older Toolkit, the bars
-- stay rows, placed by MTF as before.
function MTF.HasBarLayout()
    local toolkit = MTF.toolkit
    return type(toolkit) == "table" and type(toolkit.BAR_LAYOUT_VERSION) == "number"
        and toolkit.BAR_LAYOUT_VERSION >= 1
end

-- Where a bar button's tooltip goes: over a row; beside a column, on the side
-- of the screen with more room, so it does not cover the other buttons.
function MTF.BarTooltipAnchor(bar, widget)
    if not (widget and type(widget.GetOrientation) == "function" and widget:GetOrientation() == "vertical") then
        return "ANCHOR_TOP"
    end
    local x = bar:GetCenter()
    local width = UIParent:GetWidth()
    if type(x) == "number" and type(width) == "number"
        and x * bar:GetEffectiveScale() > width * UIParent:GetEffectiveScale() / 2 then
        return "ANCHOR_LEFT"
    end
    return "ANCHOR_RIGHT"
end

-- Messages (Announce), each with its own switch and editable text
-- (author-approved). Trade whispers: %C the count, %I the item (for Food &
-- Water, the whole list: "10 Conjured Fresh Water and 10 Conjured Bread"), %T
-- the player's full name. The portal group message and the teleport emote: %D
-- the city; in the emote, %Z your zone as it is sent and %T your name. Emotes
-- start with your name. The defaults credit MTF, as WTF's do.
MTF.ANNOUNCE_MAX_LENGTH = 255
MTF.ANNOUNCE_DEFAULTS = {
    waterWhisperText = "Here's %C %I, conjured from pure arcane energy. Drink up, %T! Courtesy of Mage Tools Forever (MTF)",
    foodWhisperText = "Here's %C %I, conjured from thin air: no crumbs, no calories. Courtesy of Mage Tools Forever (MTF)",
    bothWhisperText = "Here's %I, conjured from pure arcane energy. Eat, drink, and be merry, %T! Courtesy of Mage Tools Forever (MTF)",
    portalGroupText = "A portal to %D shimmers open! Step through before it fades. - via Mage Tools Forever (MTF)",
    teleportEmoteText = "summons powerful arcane energies to whisk themselves away to %Z. - via Mage Tools Forever (MTF)",
}
local ANNOUNCE_SWITCHES = {"waterWhisper", "foodWhisper", "bothWhisper", "portalGroup", "teleportEmote"}

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
-- Dyre's Debuff Tracker draws the Polymorph bar since 1.6.0 (John, 2026-11-20:
-- "Yes, move it"; a feature's settings and effect live in one AddOn).
MTF.COMPANIONS = {
    {addon = "DyresShieldsUp", title = "Dyre's Shields Up", what = "the shield display"},
    {addon = "DyresBuffReminders", title = "Dyre's Buff Reminders",
        what = "buff reminders, cooldown chimes, and proc arcs"},
    {addon = "DyresDebuffTracker", title = "Dyre's Debuff Tracker", what = "the Polymorph bar"},
}
-- MTF says nothing of its own about the move (lead, 2026-11-20): with Dyre's
-- Debuff Tracker loaded, its "Copied your Polymorph bar settings ..." line is
-- the only one; without it, the install line above is.
MTF.DEBUFF_TRACKER = MTF.COMPANIONS[3]

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
        -- Trade only with Shift + left-click (off by default; 2026-11-17).
        shiftTrade = conjure.shiftTrade == true,
        scale = MTF.SanitizeScale(conjure.scale),
        -- Dyre's Toolkit 2.18.0's bar layout: "vertical", else a row (nil).
        orientation = conjure.orientation == "vertical" and "vertical" or nil,
    }
    local portals = type(db.portals) == "table" and db.portals or {}
    db.portals = {
        enabled = portals.enabled ~= false,
        position = SanitizePosition(portals.position),
        scale = MTF.SanitizeScale(portals.scale),
        orientation = portals.orientation == "vertical" and "vertical" or nil,
    }
    -- MTF 1.5 and older drew the Polymorph bar: db.polymorph (enabled,
    -- position, scale, mark, macro, opacity, width, height, textScale) and
    -- the group message (announce.polymorphGroup, polymorphGroupText) stay
    -- exactly as saved. Dyre's Debuff Tracker reads them once and never
    -- writes them.
    db.polymorph = type(db.polymorph) == "table" and db.polymorph or nil
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
    if type(announce.polymorphGroup) == "boolean" then
        db.announce.polymorphGroup = announce.polymorphGroup
    end
    if type(announce.polymorphGroupText) == "string" then
        db.announce.polymorphGroupText = announce.polymorphGroupText
    end
    -- The lock is Dyre's Toolkit's (one for every Dyre's AddOn); MTF keeps a
    -- copy for its modules.
    db.locked = db.locked ~= false
    -- The toolkit's macro keeper's record of the macros MTF keeps (name ->
    -- true), so another Dyre's AddOn's macro of that name is adopted, never copied.
    local owned = type(db.ownedMacros) == "table" and db.ownedMacros or {}
    db.ownedMacros = {}
    for name, value in pairs(owned) do
        if type(name) == "string" and value == true then
            db.ownedMacros[name] = true
        end
    end
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
-- NoteFocusWorks (2.5.0) takes MTF 1.2.3's focus flag.
local TOOLKIT_CONTRACT = 2
local TOOLKIT_FUNCTIONS = {
    "RegisterAddOn", "RegisterSettingsCategory", "IsLocked", "SetLocked", "OpenSettings", "CreateWidget",
    "AddWidgetSettings", "ResetWidgets", "AddSettingsLink", "NoteFocusWorks",
}
local TOOLKIT_MISSING = "Mage Tools Forever needs Dyre's Toolkit: install or update it from CurseForge. "
    .. "MTF stays off until then."

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

-- The toolkit's lock changed: MTF's samples (the portal bar with nothing
-- known) show or hide, quietly; the toolkit says one line for all and draws
-- the outlines.
local function ApplyFramesLocked(locked)
    MTF.db.locked = locked
    MTF.RefreshConjure()
    MTF.RefreshPortals()
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

-- Dyre's Toolkit Profile (Toolkit 2.10.0; John, 2026-11-17: "one place to go
-- to persist your profile"). MTF keeps its live settings in MageToolsForeverDB;
-- the Toolkit keeps this character's copy, copies from another character or
-- the Defaults, and exports and imports it. Not in the profile (per
-- character): locked, a copy of the Toolkit's account-wide lock; ownedMacros,
-- the macros MTF keeps on this character; shield, reminders, and chimes, MTF
-- 1.1 data that Dyre's Shields Up and Dyre's Buff Reminders copy once per
-- character; polymorph, MTF 1.5 data that Dyre's Debuff Tracker reads once.
-- MageToolsForeverAccountDB is account-wide, so it is not in it.
MTF.PROFILE_CHARACTER_KEYS = {"locked", "ownedMacros", "shield", "reminders", "chimes", "polymorph"}

-- After a copy or import, out of combat (the Toolkit refuses one in combat):
-- the engine wrote the new values into MTF.db in place, so every widget holds
-- the same tables. Each part reads them again.
function MTF.ApplyProfile()
    if type(MTF.toolkit.ReapplyWidgets) == "function" then
        MTF.toolkit.ReapplyWidgets(addonName)
    end
    MTF.ApplyConjureMacros()
    -- The Toolkit does not lay the buttons out again for a copied orientation.
    MTF.LayoutConjureBar()
    MTF.RefreshConjure()
    MTF.RefreshPortals()
    local page = MTF.announcePage
    if page and page:IsShown() then
        page:OnRefresh()
    end
end

-- Once, at login, before the modules build their frames, so a part copied
-- while MTF was not loaded is written first. With a Toolkit older than
-- 2.10.0 nothing changes.
local function RegisterProfilePart()
    local register = MTF.toolkit.RegisterProfilePart
    if type(register) ~= "function" then
        return false
    end
    return register({
        addon = addonName,
        title = DEFAULT_TITLE,
        current = function() return MTF.db end,
        sanitize = function(settings) return MTF.SanitizeDB(settings) end,
        characterKeys = MTF.PROFILE_CHARACTER_KEYS,
        refresh = function() MTF.ApplyProfile() end,
    }) == true
end

SLASH_MAGETOOLSFOREVER1 = PRIMARY_SLASH
SLASH_MAGETOOLSFOREVER2 = BACKUP_SLASH
SlashCmdList[SLASH_KEY] = MTF.HandleCommand

-- Per client install (every client keeps its own SavedVariables), for all
-- characters: only MTF 1.2.3's focusWorks, true or nil, which login hands to
-- Dyre's Toolkit once (CarryFocusWorks).
function MTF.SanitizeAccountDB(db)
    return {focusWorks = type(db) == "table" and db.focusWorks == true or nil}
end

-- The Toolkit keeps one focusWorks flag for every Dyre's AddOn: MTF's own
-- (1.2.3) is carried over once and then cleared, so a later reset holds.
local function CarryFocusWorks()
    if MTF.accountDB.focusWorks == true then
        MTF.toolkit.NoteFocusWorks()
    end
    MTF.accountDB.focusWorks = nil
end

local function LoadDB()
    MageToolsForeverDB = MTF.SanitizeDB(MageToolsForeverDB)
    MTF.db = MageToolsForeverDB
    MageToolsForeverAccountDB = MTF.SanitizeAccountDB(MageToolsForeverAccountDB)
    MTF.accountDB = MageToolsForeverAccountDB
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
            message = "Mage Tools Forever does not work with this game client (it lacks " .. message
                .. "), so MTF stays off."
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
    CarryFocusWorks()
    MTF.profileRegistered = RegisterProfilePart()
    MTF.InitializeConjure()
    MTF.InitializePortals()
    MTF.InitializeOptions()
    RegisterWithToolkit()
    ReportMissingCompanions()
end)
