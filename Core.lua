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
    "CheckConjureCapabilities", "InitializeConjure", "RefreshConjure", "ResetConjurePosition",
    "ApplyConjureMacros", "ReportConjureStatus", "ReportConjureDebug", "ReportClickDebug",
    "CharacterMacrosAvailable", "WriteCharacterMacro", "DeleteCharacterMacro", "ApplyPolymorphMacro",
    "AddInputHandler", "RunOnNextInput", "RegisterMovable", "BeginDrag", "EndDrag", "ScaleKeepingCenter",
    "InitializePortals", "RefreshPortals", "ResetPortalsPosition", "ReportPortalsDebug",
    "InitializePolymorph", "RefreshPolymorph", "ResetPolymorphPosition", "ReportPolymorphDebug",
    "InitializeReminders", "RefreshReminders", "ResetRemindersPosition", "ReportRemindersDebug",
    "SanitizeReminderScale",
    "InitializeChimes", "PreviewChime", "ReportChimesDebug",
    "InitializeOptions", "OpenSettings",
}

local function CheckInstalledFiles()
    if type(MTF.ShieldDisplay) ~= "table" or type(MTF.ShieldDisplay.Initialize) ~= "function" then
        return false, "AddOn files are from different versions (missing Shield.lua). Reinstall every "
            .. "Mage Tools Forever file, then restart the client."
    end
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

-- Frame sizes in percent (author-approved): the conjure bar's here, the shield
-- display's in its own component.
MTF.SCALE_MIN = 50
MTF.SCALE_MAX = 150
MTF.SCALE_STEP = 5
MTF.DEFAULT_SCALE = 100

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

-- Seconds before a cooldown ends that its chime plays, as MageAlert does
-- (14.5 for Blink's 15), so you can act the moment it is ready.
MTF.CHIME_LEAD_MIN = 0
MTF.CHIME_LEAD_MAX = 3
MTF.CHIME_LEAD_STEP = 0.5
MTF.DEFAULT_CHIME_LEAD = 0.5

-- Spells that can chime when ready again: Classic IDs, matched by name so every
-- rank counts. cooldown is the Classic length in seconds, used until MTF reads
-- the real one out of combat. Mana Shield has no cooldown in Classic; it chimes
-- only if the client reports one. frost marks the spells Cold Snap resets.
-- Every spell starts on Talent ready (author-approved: a good sound for a
-- spell becoming available); players change any of them.
MTF.CHIME_SPELLS = {
    {key = "blink", spell = 1953, label = "Blink", cooldown = 15, on = true},
    {key = "frostnova", spell = 122, label = "Frost Nova", cooldown = 25, on = true, frost = true},
    {key = "counterspell", spell = 2139, label = "Counterspell", cooldown = 24, on = true},
    {key = "iceblock", spell = 11958, label = "Ice Block", cooldown = 300, on = true, frost = true},
    {key = "icebarrier", spell = 11426, label = "Ice Barrier", cooldown = 30, on = true, frost = true},
    {key = "manashield", spell = 1463, label = "Mana Shield", on = true},
    {key = "evocation", spell = 12051, label = "Evocation", cooldown = 480, on = true},
    {key = "coldsnap", spell = 12472, label = "Cold Snap", cooldown = 600, on = false},
    {key = "fireward", spell = 543, label = "Fire Ward", cooldown = 30, on = false},
    {key = "frostward", spell = 6143, label = "Frost Ward", cooldown = 30, on = false, frost = true},
    {key = "coneofcold", spell = 120, label = "Cone of Cold", cooldown = 10, on = false, frost = true},
    {key = "fireblast", spell = 2136, label = "Fire Blast", cooldown = 8, on = false},
    {key = "presenceofmind", spell = 12043, label = "Presence of Mind", cooldown = 180, on = false},
    {key = "arcanepower", spell = 12042, label = "Arcane Power", cooldown = 180, on = false},
    {key = "combustion", spell = 11129, label = "Combustion", cooldown = 180, on = false},
}
-- A cooldown MTF read in client, kept only when plausible.
local LEARNED_MIN = 1.5
local LEARNED_MAX = 1200

-- Chime sounds come from the library AddOn Dyre's Sounds (author-approved:
-- only it ships sound files, so players keep one copy), listed as OptionalDeps
-- so MTF loads and times chimes without it. A chime's sound is a Dyre's Sounds
-- key; MTF's older keys ("effect...", "popclick") are its aliases.
MTF.DEFAULT_CHIME_SOUND = "talent"
local SOUNDS_CONTRACT = 1
local SOUNDS_FUNCTIONS = {"List", "Groups", "Label", "Resolve", "Play", "Choices", "SetupMenu"}
local SOUNDS_WHERE = " Get it from CurseForge."
local SOUNDS_MESSAGES = {
    missing = "Install Dyre's Sounds to hear MTF's sounds (the chimes and the shield sound)." .. SOUNDS_WHERE,
    old = "Update Dyre's Sounds to hear MTF's sounds: this version is too old for MTF." .. SOUNDS_WHERE,
}

-- Dyre's Sounds with the contract and functions MTF uses, else nil and why
-- ("missing" or "old").
function MTF.SoundLibrary()
    local library = rawget(_G, "DyresSounds")
    if type(library) ~= "table" or type(library.RequireContract) ~= "function" then
        return nil, "missing"
    end
    library = library.RequireContract(SOUNDS_CONTRACT)
    if type(library) ~= "table" then
        return nil, "old"
    end
    for _, name in ipairs(SOUNDS_FUNCTIONS) do
        if type(library[name]) ~= "function" then
            return nil, "old"
        end
    end
    return library, "ok"
end

-- Says once per session what to install when the chime sounds are missing.
function MTF.ReportMissingSounds()
    local library, state = MTF.SoundLibrary()
    if library or MTF.soundsReported then
        return
    end
    MTF.soundsReported = true
    MTF.Report(SOUNDS_MESSAGES[state])
end

-- Dyre's Cooldown Chimes plays the chimes for every class (author-approved:
-- MTF stands aside for it and keeps its own chime settings, which DCC copies
-- on its first run).
function MTF.ChimesStandAside()
    if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
        return false
    end
    local loaded = C_AddOns.IsAddOnLoaded("DyresCooldownChimes")
    return loaded == true
end

-- Dyre's Buff Reminders shows buff reminders for every class (author-approved
-- two-step move): while it is loaded, MTF's own reminder icons stay hidden and
-- MTF's saved reminder settings stay as they are.
function MTF.RemindersStandAside()
    if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
        return false
    end
    local loaded = C_AddOns.IsAddOnLoaded("DyresBuffReminders")
    return loaded == true
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

function MTF.SanitizeChimeLead(value)
    if type(value) ~= "number" or value ~= value then
        return MTF.DEFAULT_CHIME_LEAD
    end
    local stepped = math.floor(value / MTF.CHIME_LEAD_STEP + 0.5) * MTF.CHIME_LEAD_STEP
    return math.max(MTF.CHIME_LEAD_MIN, math.min(MTF.CHIME_LEAD_MAX, stepped))
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

-- A saved sound key in Dyre's Sounds' spelling, or nil when it knows no such
-- sound. Without the library a saved key is kept as it is, so a missing
-- library never resets a choice.
local function SavedSound(key)
    if type(key) ~= "string" then
        return nil
    end
    local library = MTF.SoundLibrary()
    if not library then
        return key
    end
    return library.Resolve(key)
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
    }
    local reminders = type(db.reminders) == "table" and db.reminders or {}
    local reminderSpells = type(reminders.spells) == "table" and reminders.spells or {}
    local reminderIcons = type(reminders.icons) == "table" and reminders.icons or {}
    local reminderLast = type(reminders.last) == "table" and reminders.last or {}
    db.reminders = {enabled = reminders.enabled ~= false, group = reminders.group ~= false, spells = {}, icons = {},
        last = {}}
    for _, reminder in ipairs(MTF.REMINDERS or {}) do
        local spell = reminderSpells[reminder.key]
        if type(spell) == "boolean" then
            db.reminders.spells[reminder.key] = spell
        else
            db.reminders.spells[reminder.key] = reminder.on
        end
        local icon = type(reminderIcons[reminder.key]) == "table" and reminderIcons[reminder.key] or {}
        if type(reminderLast[reminder.key]) == "string" then
            db.reminders.last[reminder.key] = reminderLast[reminder.key]
        end
        db.reminders.icons[reminder.key] = {position = SanitizePosition(icon.position),
            scale = MTF.SanitizeReminderScale(icon.scale)}
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
    -- The shield display is a self-contained component; it owns its defaults.
    if MTF.ShieldDisplay then
        db.shield = MTF.ShieldDisplay.Sanitize(db.shield)
    end
    -- One lock for every frame (author-approved), locked by default; each
    -- frame reads its own copy, the shield component from its settings.
    db.locked = db.locked ~= false
    db.grid = db.grid ~= false
    db.conjure.locked = db.locked
    if type(db.shield) == "table" then
        db.shield.locked = db.locked
    end
    local chimes = type(db.chimes) == "table" and db.chimes or {}
    local spells = type(chimes.spells) == "table" and chimes.spells or {}
    local learned = type(chimes.learned) == "table" and chimes.learned or {}
    local sounds = type(chimes.sounds) == "table" and chimes.sounds or {}
    -- The one sound every chime used before each had its own.
    local formerSound = SavedSound(chimes.sound)
    db.chimes = {
        enabled = chimes.enabled ~= false,
        lead = MTF.SanitizeChimeLead(chimes.lead),
        spells = {},
        sounds = {},
        learned = {},
    }
    for _, chime in ipairs(MTF.CHIME_SPELLS) do
        if type(spells[chime.key]) == "boolean" then
            db.chimes.spells[chime.key] = spells[chime.key]
        else
            db.chimes.spells[chime.key] = chime.on
        end
        db.chimes.sounds[chime.key] = SavedSound(sounds[chime.key]) or formerSound or MTF.DEFAULT_CHIME_SOUND
        local seconds = learned[chime.key]
        if type(seconds) == "number" and seconds >= LEARNED_MIN and seconds <= LEARNED_MAX then
            db.chimes.learned[chime.key] = seconds
        end
    end
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

-- The shield display (Shield.lua) is a component other AddOns may ship too; MTF
-- hands it MTF's settings and chat, and it decides whether this copy draws.
function MTF.InitializeShield()
    MTF.ShieldDisplay.Initialize({settings = function() return MTF.db.shield end, report = MTF.Report,
        unlockHint = "Drag to move · /mtf lock when done", missingSounds = MTF.ReportMissingSounds})
end

function MTF.RefreshShield()
    MTF.ShieldDisplay.Refresh()
    MTF.ShieldDisplay.ApplyBreakSound()
end

function MTF.ResetShieldPosition()
    MTF.ShieldDisplay.ResetPosition()
end

function MTF.ReportShieldDebug()
    MTF.ShieldDisplay.ReportDebug(MTF.Report)
end

-- /mtf unlock and /mtf lock, and the main page's "Unlock frames to move them":
-- one lock for the conjure bar and the shield display together.
-- While unlocked, a frame shows a gold outline and a hint (author-approved).
-- A plain child, so it can show and hide also in combat.
function MTF.CreateMover(frame)
    local mover = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mover:SetPoint("TOPLEFT", -4, 4)
    mover:SetPoint("BOTTOMRIGHT", 4, -4)
    mover:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
    mover:SetBackdropBorderColor(1, 0.82, 0)
    mover.hint = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mover.hint:SetPoint("BOTTOM", mover, "TOP", 0, 2)
    mover.hint:SetText("Drag to move · /mtf lock when done")
    mover:SetShown(not MTF.db.locked)
    return mover
end

-- While unlocked, an alignment grid over the screen (author-approved): faint
-- lines every GRID_SPACING from the center out, and the center lines in red,
-- so frames line up with the middle of the screen. Under every frame, it takes
-- no mouse. Rebuilt when the screen size or UI scale changes.
local GRID_SPACING = 32
local GRID_LINE = {1, 1, 1, 0.12}
local GRID_CENTER = {1, 0.2, 0.2, 0.7}
local grid

local function GridLine(vertical, offset, color, thickness)
    local line = grid:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(color[1], color[2], color[3], color[4])
    if vertical then
        line:SetPoint("TOP", grid, "TOP", offset, 0)
        line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
        line:SetWidth(thickness)
    else
        line:SetPoint("LEFT", grid, "LEFT", 0, offset)
        line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
        line:SetHeight(thickness)
    end
    grid.lines[#grid.lines + 1] = line
end

local function BuildGrid()
    for _, line in ipairs(grid.lines) do
        line:Hide()
    end
    grid.lines = {}
    local halfWidth, halfHeight = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    for step = 1, math.floor(halfWidth / GRID_SPACING) do
        GridLine(true, step * GRID_SPACING, GRID_LINE, 1)
        GridLine(true, -step * GRID_SPACING, GRID_LINE, 1)
    end
    for step = 1, math.floor(halfHeight / GRID_SPACING) do
        GridLine(false, step * GRID_SPACING, GRID_LINE, 1)
        GridLine(false, -step * GRID_SPACING, GRID_LINE, 1)
    end
    GridLine(true, 0, GRID_CENTER, 2)
    GridLine(false, 0, GRID_CENTER, 2)
    grid.built = true
end

function MTF.RefreshGrid()
    local wanted = not MTF.db.locked and MTF.db.grid
    if not grid then
        if not wanted then
            return
        end
        grid = CreateFrame("Frame", nil, UIParent)
        grid:SetAllPoints(UIParent)
        grid:SetFrameStrata("BACKGROUND")
        grid:EnableMouse(false)
        grid.lines = {}
        grid:SetScript("OnEvent", function() grid.built = false; MTF.RefreshGrid() end)
        grid:RegisterEvent("DISPLAY_SIZE_CHANGED")
        grid:RegisterEvent("UI_SCALE_CHANGED")
    end
    if wanted and not grid.built then
        BuildGrid()
    end
    grid:SetShown(wanted)
    MTF.grid = grid
end

function MTF.SetFramesLocked(locked)
    MTF.db.locked = locked
    MTF.db.conjure.locked = locked
    MTF.db.shield.locked = locked
    MTF.RefreshConjure()
    MTF.RefreshPortals()
    MTF.RefreshPolymorph()
    MTF.RefreshReminders()
    MTF.RefreshShield()
    MTF.RefreshGrid()
    if locked then
        MTF.Report("All MTF frames locked.")
    else
        MTF.Report("All MTF frames unlocked: drag them where you want (Shift-drag moves a snapped group; "
            .. "scroll over a buff reminder to resize it), then type /mtf lock.")
    end
end

function MTF.Unlock()
    MTF.SetFramesLocked(false)
end

function MTF.Lock()
    MTF.SetFramesLocked(true)
end

-- /mtf reset: the conjure bar and the shield display back to their default places.
function MTF.ResetPositions()
    MTF.ResetConjurePosition()
    MTF.ResetPortalsPosition()
    MTF.ResetPolymorphPosition()
    MTF.ResetRemindersPosition()
    MTF.ResetShieldPosition()
    if InCombatLockdown() then
        MTF.Report("MTF frames move back to their default places after combat.")
    end
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
    MTF.InitializeConjure()
    MTF.InitializePortals()
    MTF.InitializePolymorph()
    MTF.InitializeReminders()
    MTF.InitializeShield()
    MTF.InitializeChimes()
    MTF.InitializeOptions()
    MTF.RefreshGrid()
end)
