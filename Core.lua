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

-- Chime sounds: the client's own interface sounds, by SOUNDKIT name, from the
-- pinned SoundKitConstants. A name the client lacks is left out of the list.
MTF.CHIME_SOUNDS = {
    -- Dyre's Picks, first (author-approved): the AddOn's own sounds, shipped in
    -- Sounds/ with the shield display's break sounds and played by file.
    {key = "effectfadingslow", label = "Dyre's Picks: Fading slow disappear", file = "FadingSlowDisappear.mp3"},
    {key = "effectblowswoosh", label = "Dyre's Picks: Disappear blow swoosh", file = "DisappearBlowSwoosh.mp3"},
    {key = "effectcartoonvanish", label = "Dyre's Picks: Cartoon vanish", file = "CartoonVanish.mp3"},
    {key = "effectdisappear", label = "Dyre's Picks: Disappear", file = "Disappear.mp3"},
    {key = "effectmagical", label = "Dyre's Picks: Magical disappear", file = "MagicalDisappear.mp3"},
    {key = "effectdisappearshort", label = "Dyre's Picks: Disappear (short)", file = "DisappearShort.wav"},
    {key = "effectdisappearingswoosh", label = "Dyre's Picks: Disappearing swoosh", file = "DisappearingSwoosh.wav"},
    {key = "effectteleportvanish", label = "Dyre's Picks: Teleport warp vanish", file = "TeleportWarpVanish.wav"},
    {key = "effectslowswoosh", label = "Dyre's Picks: Slow swoosh", file = "SlowSwoosh.wav"},
    -- The client's interface sounds, by SOUNDKIT name.
    {key = "mapping", label = "Interface: Map ping", kit = "MAP_PING"},
    {key = "whisper", label = "Interface: Whisper", kit = "TELL_MESSAGE"},
    {key = "invite", label = "Interface: Group invite", kit = "IG_PLAYER_INVITE"},
    {key = "readycheck", label = "Interface: Ready check", kit = "READY_CHECK"},
    {key = "raidwarning", label = "Interface: Raid warning", kit = "RAID_WARNING"},
    {key = "toast", label = "Interface: Friend toast", kit = "UI_BNET_TOAST"},
    {key = "talent", label = "Interface: Talent ready", kit = "UI_ORDERHALL_TALENT_READY_TOAST"},
    {key = "click", label = "Interface: Soft click", kit = "UI_IG_STORE_PAGE_NAV_BUTTON"},
    {key = "auction", label = "Interface: Auction bell", kit = "AUCTION_WINDOW_OPEN"},
    {key = "alarm", label = "Interface: Alarm clock", kit = "ALARM_CLOCK_WARNING_2"},
    -- The Cooldown Manager's alert sounds, by sound kit ID and in its categories,
    -- generated from the pinned Blizzard_CooldownViewer/CooldownViewerSoundAlertData.lua
    -- (author-approved: the same scheme, both sets in every dropdown). Names as
    -- Blizzard's comments give them, "Guiter" corrected; categories as its menu
    -- names them (War2 and War3 show as "Warcraft 2" and "Warcraft 3").
    {key = "animalscat", label = "Animals: Cat", id = 316401},
    {key = "animalschicken", label = "Animals: Chicken", id = 316406},
    {key = "animalscow", label = "Animals: Cow", id = 316407},
    {key = "animalsgnoll", label = "Animals: Gnoll", id = 316409},
    {key = "animalsgoat", label = "Animals: Goat", id = 316715},
    {key = "animalslion", label = "Animals: Lion", id = 316411},
    {key = "animalspanther", label = "Animals: Panther", id = 316412},
    {key = "animalsrattlesnake", label = "Animals: Rattlesnake", id = 316413},
    {key = "animalssheep", label = "Animals: Sheep", id = 316414},
    {key = "animalswolf", label = "Animals: Wolf", id = 316415},
    {key = "devicesboathorn", label = "Devices: Boat Horn", id = 316442},
    {key = "devicesairhorn", label = "Devices: Air Horn", id = 316436},
    {key = "devicesbikehorn", label = "Devices: Bike Horn", id = 316713},
    {key = "devicescashregister", label = "Devices: Cash Register", id = 316446},
    {key = "devicesjackpotbell", label = "Devices: Jackpot Bell", id = 316717},
    {key = "devicesjackpotcoins", label = "Devices: Jackpot Coins", id = 316718},
    {key = "devicesjackpotfail", label = "Devices: Jackpot Fail", id = 316719},
    {key = "devicesrotaryphonedial", label = "Devices: Rotary Phone Dial", id = 316433},
    {key = "devicesrotaryphonering", label = "Devices: Rotary Phone Ring", id = 316492},
    {key = "devicesstovepipe", label = "Devices: Stove Pipe", id = 316425},
    {key = "devicestrashcanlid", label = "Devices: Trashcan Lid", id = 316430},
    {key = "impactsanvilstrike", label = "Impacts: Anvil Strike", id = 316528},
    {key = "impactsbubblesmash", label = "Impacts: Bubble Smash", id = 316419},
    {key = "impactslowthud", label = "Impacts: Low Thud", id = 316531},
    {key = "impactsmetalclanks", label = "Impacts: Metal Clanks", id = 316532},
    {key = "impactsmetalrattle", label = "Impacts: Metal Rattle", id = 316486},
    {key = "impactsmetalscrape", label = "Impacts: Metal Scrape", id = 316484},
    {key = "impactsmetalwarble", label = "Impacts: Metal Warble", id = 316536},
    {key = "impactspopclick", label = "Impacts: Pop Click", id = 316434},
    {key = "impactsstrangeclang", label = "Impacts: Strange Clang", id = 316453},
    {key = "impactsswordscrape", label = "Impacts: Sword Scrape", id = 316535},
    {key = "instrumentsbellring", label = "Instruments: Bell Ring", id = 316493},
    {key = "instrumentsbelltrill", label = "Instruments: Bell Trill", id = 316712},
    {key = "instrumentsbrass", label = "Instruments: Brass", id = 316722},
    {key = "instrumentschimeascending", label = "Instruments: Chime Ascending", id = 316447},
    {key = "instrumentsguitarchug", label = "Instruments: Guitar Chug", id = 316477},
    {key = "instrumentsguitarpinch", label = "Instruments: Guitar Pinch", id = 316482},
    {key = "instrumentspitchpipedistressed", label = "Instruments: Pitch Pipe Distressed", id = 316509},
    {key = "instrumentspitchpipenote", label = "Instruments: Pitch Pipe Note", id = 316501},
    {key = "instrumentssynthbig", label = "Instruments: Synth Big", id = 316540},
    {key = "instrumentssynthbuzz", label = "Instruments: Synth Buzz", id = 316476},
    {key = "instrumentssynthhigh", label = "Instruments: Synth High", id = 316460},
    {key = "instrumentswarhorn", label = "Instruments: Warhorn", id = 316723},
    {key = "shortbellstrike", label = "Short: Bell Strike", id = 353392},
    {key = "shortbelltree", label = "Short: Bell Tree", id = 353387},
    {key = "shortbigpot", label = "Short: Big Pot", id = 353388},
    {key = "shortblades", label = "Short: Blades", id = 353389},
    {key = "shortcoffeemug", label = "Short: Coffee Mug", id = 353424},
    {key = "shortcowbell", label = "Short: Cow Bell", id = 353393},
    {key = "shortfingersnap", label = "Short: Finger Snap", id = 353395},
    {key = "shortguitar", label = "Short: Guitar", id = 353404},
    {key = "shortkalimba", label = "Short: Kalimba", id = 353405},
    {key = "shortmetalbladedrop", label = "Short: Metal Blade Drop", id = 353406},
    {key = "shortmetalbladeonrod", label = "Short: Metal Blade On Rod", id = 353407},
    {key = "shortmetalimpact", label = "Short: Metal Impact", id = 353408},
    {key = "shortminiwoodxylophone", label = "Short: Mini Wood Xylophone", id = 353410},
    {key = "shortpapercup", label = "Short: Paper Cup", id = 353425},
    {key = "shortsheetmetal", label = "Short: Sheet Metal", id = 353417},
    {key = "shortstovepipe", label = "Short: Stove Pipe", id = 353419},
    {key = "shortstovepipeblade", label = "Short: Stove Pipe Blade", id = 353420},
    {key = "shortswordshing", label = "Short: Sword Shing", id = 353421},
    {key = "shortsynthbleep", label = "Short: Synth Bleep", id = 353402},
    {key = "shortsynthblurp", label = "Short: Synth Blurp", id = 353400},
    {key = "shortsyntherror", label = "Short: Synth Error", id = 353397},
    {key = "shortsynthhigh", label = "Short: Synth High", id = 353399},
    {key = "shorttriangle", label = "Short: Triangle", id = 353423},
    {key = "shortwaterdrop", label = "Short: Water Drop", id = 353426},
    {key = "shortwinebottle", label = "Short: Wine Bottle", id = 353427},
    {key = "shortwoodxylophone", label = "Short: Wood Xylophone", id = 353428},
    {key = "war2abstractwhoosh", label = "Warcraft 2: Abstract Whoosh", id = 316731},
    {key = "war2choir", label = "Warcraft 2: Choir", id = 316733},
    {key = "war2construction", label = "Warcraft 2: Construction", id = 316735},
    {key = "war2magicchimes", label = "Warcraft 2: Magic Chimes", id = 316736},
    {key = "war2pigsqueal", label = "Warcraft 2: Pig Squeal", id = 316745},
    {key = "war2saws", label = "Warcraft 2: Saws", id = 316738},
    {key = "war2seal", label = "Warcraft 2: Seal", id = 316746},
    {key = "war2slow", label = "Warcraft 2: Slow", id = 316748},
    {key = "war2smith", label = "Warcraft 2: Smith", id = 316749},
    {key = "war2synthstinger", label = "Warcraft 2: Synth Stinger", id = 316739},
    {key = "war2trumpetrally", label = "Warcraft 2: Trumpet Rally", id = 316740},
    {key = "war2zippymagic", label = "Warcraft 2: Zippy Magic", id = 316737},
    {key = "war3bell", label = "Warcraft 3: Bell", id = 316773},
    {key = "war3crunchybell", label = "Warcraft 3: Crunchy Bell", id = 316774},
    {key = "war3drumsplash", label = "Warcraft 3: Drum Splash", id = 316768},
    {key = "war3error", label = "Warcraft 3: Error", id = 316775},
    {key = "war3fanfare", label = "Warcraft 3: Fanfare", id = 316769},
    {key = "war3gateopen", label = "Warcraft 3: Gate Open", id = 316776},
    {key = "war3gold", label = "Warcraft 3: Gold", id = 316770},
    {key = "war3magicshimmer", label = "Warcraft 3: Magic Shimmer", id = 316778},
    {key = "war3ringout", label = "Warcraft 3: Ringout", id = 316771},
    {key = "war3rooster", label = "Warcraft 3: Rooster", id = 316765},
    {key = "war3shimmerbell", label = "Warcraft 3: Shimmer Bell", id = 316779},
    {key = "war3wolfhowl", label = "Warcraft 3: Wolf Howl", id = 316766},
    -- The game's text-to-speech says the spell, as MageAlert's voice clips did,
    -- last as in the Cooldown Manager's menu.
    {key = "voice", label = "Text to Speech", voice = true},
}
MTF.DEFAULT_CHIME_SOUND = "talent"

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

-- Keys saved before the Cooldown Manager catalog, mapped to its keys.
local SOUND_ALIASES = {popclick = "impactspopclick"}

local function ValidSound(key)
    key = SOUND_ALIASES[key] or key
    for _, sound in ipairs(MTF.CHIME_SOUNDS) do
        if sound.key == key then
            return key
        end
    end
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
    local formerSound = ValidSound(chimes.sound)
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
        db.chimes.sounds[chime.key] = ValidSound(sounds[chime.key]) or formerSound or MTF.DEFAULT_CHIME_SOUND
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
        unlockHint = "Drag to move · /mtf lock when done"})
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
