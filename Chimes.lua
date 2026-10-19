local _, MTF = ...

-- Cooldown chimes: a sound just before Blink, Frost Nova, and your other
-- chosen spells are ready again (author-approved, after MageAlert), also in
-- combat. The client hides cooldown details from AddOns in combat and offers
-- no event when a cooldown ends, and the combat log MageAlert used is closed
-- to AddOns. So MTF times each cooldown itself from your own cast, which stays
-- readable in combat: it uses the length it last read for that spell out of
-- combat, else Classic's, and right after an out-of-combat cast it reads the
-- real time left. Cold Snap resets your Frost spells, so it cancels their
-- chimes. The sounds come from Dyre's Sounds, and while Dyre's Cooldown Chimes
-- is loaded MTF plays none: DCC plays them.

-- Seconds after a cast before MTF reads its cooldown, once the client has set it.
local READ_DELAY = 0.1
-- Shorter cooldowns are the global cooldown, not the spell's own.
local GLOBAL_COOLDOWN = 1.5

local chimes = {byName = {}, generation = {}, readyAt = {}, lastCast = nil, log = {}}
-- The latest casts, schedules, and chimes, for /mtf debug_chimes.
local LOG_SIZE = 12

local function Log(text)
    table.insert(chimes.log, 1, {time = GetTime(), text = text})
    chimes.log[LOG_SIZE + 1] = nil
end

local function Timers()
    return type(C_Timer) == "table" and type(C_Timer.After) == "function"
end

-- A chime's own sound through Dyre's Sounds; Text to Speech says
-- "<Spell> ready". A sound the client cannot play (no voice installed) falls
-- back to the default. Without the library nothing plays, and MTF says once
-- what to install. While Dyre's Cooldown Chimes is loaded, it plays them.
local function Play(chime)
    if MTF.ChimesStandAside() then
        return false
    end
    local library = MTF.SoundLibrary()
    if not library then
        MTF.ReportMissingSounds()
        return false
    end
    local speech = chime.label .. " ready"
    if library.Play(MTF.db.chimes.sounds[chime.key], speech) then
        return true
    end
    return library.Play(MTF.DEFAULT_CHIME_SOUND, speech)
end

-- Plays a chime's sound once, so the settings page can preview it.
function MTF.PreviewChime(key)
    for _, chime in ipairs(MTF.CHIME_SPELLS) do
        if chime.key == key then
            Play(chime)
        end
    end
end

local function Cancel(chime)
    chimes.generation[chime.key] = (chimes.generation[chime.key] or 0) + 1
    chimes.readyAt[chime.key] = nil
end

-- Chimes `lead` seconds before a cooldown of this many seconds ends; a newer
-- schedule for the same spell replaces this one.
local function Schedule(chime, seconds, source)
    Cancel(chime)
    local generation = chimes.generation[chime.key]
    chimes.readyAt[chime.key] = GetTime() + seconds
    Log(string.format("scheduled %s #%d in %.1fs (%s)", chime.key, generation, seconds, source))
    C_Timer.After(math.max(0, seconds - MTF.db.chimes.lead), function()
        if chimes.generation[chime.key] ~= generation then
            return
        end
        chimes.readyAt[chime.key] = nil
        if MTF.db.chimes.enabled and MTF.db.chimes.spells[chime.key] then
            Log(string.format("played %s #%d", chime.key, generation))
            Play(chime)
        end
    end)
end

-- The cooldown as the client reports it, or nil while it is secret or idle.
local function ReadCooldown(spellID)
    if type(C_Spell.GetSpellCooldown) ~= "function" then
        return nil
    end
    local info = C_Spell.GetSpellCooldown(spellID)
    if type(info) ~= "table" then
        return nil
    end
    local start, duration = info.startTime, info.duration
    if MTF.IsSecret(start) or MTF.IsSecret(duration) or type(start) ~= "number" or type(duration) ~= "number"
        or duration <= GLOBAL_COOLDOWN then
        return nil
    end
    return duration, start + duration - GetTime()
end

-- Right after a cast, the real cooldown: learned for next time, and the
-- chime rescheduled to it.
local function Refine(chime, spellID)
    local duration, left = ReadCooldown(spellID)
    if not duration then
        return
    end
    MTF.db.chimes.learned[chime.key] = math.floor(duration * 10 + 0.5) / 10
    if left > 0 then
        Schedule(chime, left, "read")
    end
end

local function OnCast(spellID)
    if MTF.IsSecret(spellID) or type(spellID) ~= "number" then
        return
    end
    local chime = chimes.byName[C_Spell.GetSpellName(spellID)]
    if not chime then
        return
    end
    chimes.lastCast = {key = chime.key, spell = spellID, time = GetTime()}
    Log(string.format("cast %s spell=%d", chime.key, spellID))
    if chime.key == "coldsnap" then
        for _, other in ipairs(MTF.CHIME_SPELLS) do
            if other.frost then
                Cancel(other)
            end
        end
    end
    local seconds = MTF.db.chimes.learned[chime.key] or chime.cooldown
    if seconds then
        Schedule(chime, seconds, MTF.db.chimes.learned[chime.key] and "learned" or "classic")
    end
    C_Timer.After(READ_DELAY, function() Refine(chime, spellID) end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, _, _, _, spellID)
    OnCast(spellID)
end)

function MTF.InitializeChimes()
    if not Timers() then
        MTF.Report("Cooldown chimes stay off: this client lacks C_Timer.After.")
        return
    end
    for _, chime in ipairs(MTF.CHIME_SPELLS) do
        local name = C_Spell.GetSpellName(chime.spell)
        if name then
            chimes.byName[name] = chime
        end
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    if MTF.db.chimes.enabled and not MTF.ChimesStandAside() then
        MTF.ReportMissingSounds()
    end
end

-- /mtf debug_chimes: each chime spell as the client knows it, whether its
-- cooldown is readable now, the length MTF uses, and the sound.
function MTF.ReportChimesDebug()
    local function Report(text)
        MTF.Report("debug_chimes " .. text)
    end
    local secrecy = type(C_Secrets) == "table" and type(C_Secrets.GetSpellCooldownSecrecy) == "function"
    local now = GetTime()
    for _, chime in ipairs(MTF.CHIME_SPELLS) do
        local known = type(C_SpellBook) == "table" and type(C_SpellBook.IsSpellKnown) == "function"
            and C_SpellBook.IsSpellKnown(chime.spell)
        local readAt = MTF.db and MTF.db.chimes.learned[chime.key]
        local duration = ReadCooldown(chime.spell)
        -- The client returns no value for an unknown spell; tostring needs one.
        local name = C_Spell.GetSpellName(chime.spell)
        Report(string.format("%s name=%s known=%s on=%s sound=%s classic=%s learned=%s readNow=%s secrecy=%s readyIn=%s",
            chime.key, tostring(name), tostring(known),
            tostring(MTF.db and MTF.db.chimes.spells[chime.key]), tostring(MTF.db and MTF.db.chimes.sounds[chime.key]),
            tostring(chime.cooldown), tostring(readAt),
            tostring(duration), secrecy and MTF.Describe(C_Secrets.GetSpellCooldownSecrecy(chime.spell)) or "n/a",
            chimes.readyAt[chime.key] and string.format("%.1fs", chimes.readyAt[chime.key] - now) or "-"))
    end
    local last = chimes.lastCast
    local _, sounds = MTF.SoundLibrary()
    Report(string.format("sounds=%s playedByDCC=%s lead=%s lastCast=%s", sounds, tostring(MTF.ChimesStandAside()),
        tostring(MTF.db and MTF.db.chimes.lead),
        last and string.format("%s %.1fs ago", last.key, now - last.time) or "none"))
    for _, entry in ipairs(chimes.log) do
        Report(string.format("log %.1fs ago %s", now - entry.time, entry.text))
    end
end
