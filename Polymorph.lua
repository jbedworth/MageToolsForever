local _, MTF = ...

-- Polymorph bar (author-approved): one block in WTF's Bars format, the
-- sheeped mob's name above a bar that drains with the Polymorph's time left.
-- Only one Polymorph of yours can be up at a time, so there is one bar.
--
-- On Forever, AddOn code cannot read enemy auras in combat, so the bar is a
-- Blizzard AuraContainer slot, as in WTF's DoT tracker: the engine reads the
-- mob's unit and draws the icon, bar, and time left into regions MTF made;
-- MTF never sees the timer. MTF knows which mob you sheeped from your own cast
-- events, binds the container to that mob's nameplate, target, or focus, and
-- forgets it when it dies or the longest Polymorph could have ended. A dim
-- line stays behind the bar, so a Polymorph that broke early shows as gone.
--
-- On cast, MTF can tell the group (Announce). The moon (author-approved) comes
-- only from the "! Polymorph" macro and the bar's click: their /tm runs at the
-- key press, which the game allows, also in combat. MTF never calls
-- SetRaidTarget: from AddOn code the game forbade it even out of combat
-- (ADDON_ACTION_FORBIDDEN in client, 0.3.3). The combat log is closed to
-- AddOns, so a resist cannot be seen; a successful cast counts as landed.
--
-- Clicking the bar re-sheeps your focus (author-approved: single-target
-- control follows the focus, as the "! Polymorph" macro sets it), or, with no
-- focus, targets the mob by name, casts Polymorph, and goes back to your
-- target. Secure attributes change only
-- out of combat, so the click is set as the cast starts (a pull's Polymorph
-- starts before combat); one begun in combat on a different mob updates the
-- click when combat ends. The secure button holds the bar's place; the
-- bar is an ordinary frame on top, so it can show and hide in combat.

-- Classic IDs: Polymorph ranks, then Pig, Turtle, and Cow. Every spellbook
-- spell of the same names counts too.
local POLYMORPH_IDS = {118, 12824, 12825, 12826, 28272, 28271, 28270}
local LONGEST_SECONDS = 50
local FORGET_SLACK = 5
local MOON = 5
-- Blizzard's /tm runs from the key press, untainted, so it marks in combat too
-- (pinned SlashCommands.lua). "!" keeps a second press from toggling the moon
-- off; "exists" keeps it from marking with nothing there. The macros cast with
-- /use, which casts a spell of that name (author: every letter counts), and
-- every @focus condition has exists (author). The mark switch decides
-- whether the macro and the click have their /tm line.
local MARK_FOCUS = "/tm [@focus,harm,nodead,exists] !" .. MOON .. "\n"
local MARK_TARGET = "/tm [@target,harm,nodead,exists] !" .. MOON .. "\n"

local function MarkLine(line)
    return MTF.db.polymorph.mark and line or ""
end
local AURA_FILTER = "HARMFUL|PLAYER"
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local MAX_NAMEPLATE_UNITS = 40
local ANNOUNCE_REPEAT_SECONDS = 3

-- WTF's Bars theme: the name line, then a bar line with an icon. The width,
-- the bar line's height, and the text size are settings (Core's
-- POLYMORPH_SIZE_SPECS); at the defaults the name line is 18, the icon 14.
local HEADER = 18
local ICON_INSET = 2
local PADDING = 6
local NAME_FONT = "GameFontHighlightSmall"
local LABEL_FONT = "GameFontDisableSmall"
-- Slider steps come quickly while a slider is dragged: the look follows each
-- at once, and the rebuild runs once, this long after the last.
local BUILD_DELAY = 0.2
local BROWN = {0.28, 0.16, 0.07, 0.85}
local IDLE_BORDER = {0.45, 0.35, 0.2}
local LINE_BACKGROUND = {0.1, 0.1, 0.1, 0.6}
local BAR_COLOR = {0.75, 0.45, 0.95}
local PLACEHOLDER_ALPHA = 0.3
local DEFAULT_POINT = {point = "CENTER", relativePoint = "CENTER", x = -260, y = 60}
local SAMPLE_NAME = "Polymorph (sample)"

local sheep = {available = false, casts = {}, ids = {}, names = {}}
local holder, bar

local function ReadGUID(unit)
    local guid = UnitGUID(unit)
    if MTF.IsSecret(guid) or type(guid) ~= "string" then
        return nil
    end
    return guid
end

local function ReadName(unit)
    local name = UnitName(unit)
    if MTF.IsSecret(name) or type(name) ~= "string" then
        return nil
    end
    return name
end

local function IsDead(unit)
    local dead = UnitIsDead(unit)
    return not MTF.IsSecret(dead) and dead == true
end

local function HasAuraContainer()
    if type(C_XMLUtil) ~= "table" or type(C_XMLUtil.GetTemplateInfo) ~= "function"
        or type(C_AddOns) ~= "table" or type(C_AddOns.LoadAddOn) ~= "function" then
        return false
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    return C_XMLUtil.GetTemplateInfo(CONTAINER_TEMPLATE) ~= nil
end

-- Every Polymorph spell ID: the Classic ones and the spellbook's of the same
-- names, so Forever's own ranks count.
local function BuildSpellSet()
    local ids, names = {}, {}
    for _, id in ipairs(POLYMORPH_IDS) do
        ids[id] = true
        local name = C_Spell.GetSpellName(id)
        if name then
            names[name] = true
        end
    end
    if type(C_SpellBook) == "table" and type(C_SpellBook.GetNumSpellBookSkillLines) == "function" then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if type(lineInfo) == "table" then
                for index = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                    if type(item) == "table" and type(item.spellID) == "number" and names[item.name] then
                        ids[item.spellID] = true
                    end
                end
            end
        end
    end
    sheep.ids, sheep.names = ids, names
end

local function KnowsPolymorph()
    for id in pairs(sheep.ids) do
        if C_SpellBook.IsSpellKnown(id) == true then
            return true
        end
    end
    return false
end

-- The unit showing this mob now: your focus (it stays on the mob when its
-- nameplate drops), your target, else its nameplate (whose token can change
-- as it leaves plate range and comes back; its GUID does not). Not mouseover:
-- it changes with the pointer and has no event MTF rebinds on.
local function FindUnit(guid)
    if not guid then
        return nil
    end
    for _, unit in ipairs({"focus", "target"}) do
        if ReadGUID(unit) == guid then
            return unit
        end
    end
    for index = 1, MAX_NAMEPLATE_UNITS do
        local unit = "nameplate" .. index
        if UnitExists(unit) and ReadGUID(unit) == guid then
            return unit
        end
    end
end

-- The unit a cast sent at targetName went to: the first that matches by name.
local function FindCastUnit(targetName)
    for _, unit in ipairs({"target", "focus", "mouseover"}) do
        if UnitExists(unit) and ReadName(unit) == targetName then
            return unit
        end
    end
    for index = 1, MAX_NAMEPLATE_UNITS do
        local unit = "nameplate" .. index
        if UnitExists(unit) and ReadName(unit) == targetName then
            return unit
        end
    end
end

local function Bind(unit)
    local wanted = unit or "none"
    if not bar.container or bar.boundUnit == wanted then
        return
    end
    bar.boundUnit = wanted
    bar.container:SetUnit(wanted)
    bar.container:UpdateAllAuras()
end

-- Display ----------------------------------------------------------------------

local function Layout()
    local settings = MTF.db.polymorph
    local sample = not MTF.db.locked
    if not settings.enabled then
        bar:Hide()
        return
    end
    if sheep.guid then
        -- In combat the click cannot follow a new mob: say whom it sheeps.
        local click = holder.mobName
        if click and click ~= sheep.mobName then
            bar.name:SetText(sheep.mobName .. "  |cff999999(click: " .. click .. ")|r")
        else
            bar.name:SetText(sheep.mobName)
        end
        bar:Show()
    elseif sample then
        bar.name:SetText(SAMPLE_NAME)
        bar:Show()
    else
        bar:Hide()
    end
end

-- Out of combat only: the secure click and whether the holder is there.
local function ApplyClick()
    if InCombatLockdown() then
        sheep.clickDirty = true
        return
    end
    sheep.clickDirty = false
    local settings = MTF.db.polymorph
    -- The holder is secure: its click, whether it is there, and its mouse
    -- change only here, out of combat (in client a Polymorph that landed in
    -- combat once rescaled it there, after which its clicks failed). Its
    -- place and size are Dyre's Toolkit's, which also waits out combat.
    local name, spell = sheep.clickName, sheep.clickSpell
    if name and spell then
        -- A missing mob leaves no target, so nothing else gets sheeped.
        holder:SetAttribute("type1", "macro")
        holder:SetAttribute("macrotext1", MarkLine(MARK_FOCUS) .. "/use [@focus,exists,harm,nodead] " .. spell
            .. "\n/stopmacro [@focus,exists]\n/cleartarget\n/targetexact " .. name
            .. "\n" .. MarkLine(MARK_TARGET) .. "/use [@target,harm,nodead] " .. spell .. "\n/targetlasttarget")
    else
        holder:SetAttribute("type1", nil)
        holder:SetAttribute("macrotext1", nil)
    end
    holder.mobName, holder.spellName = name, spell
    -- Shown while unlocked even before you learn Polymorph, so it can be placed.
    holder:SetShown(settings.enabled and (KnowsPolymorph() or not MTF.db.locked))
    -- The holder is invisible: it takes the mouse only while it has a sheep
    -- to click or is unlocked to drag, so clicks pass through to the world
    -- (players could not click through it with no bar shown). Secure: out of
    -- combat only, so after a sheep forgotten in combat the clicks pass
    -- through again when combat ends.
    holder:EnableMouse(not MTF.db.locked or (name ~= nil and spell ~= nil))
    Layout()
end

local function Forget()
    sheep.guid, sheep.mobName, sheep.clickName = nil, nil, nil
    Bind(nil)
    Layout()
    ApplyClick()
end

local function Track(guid, mobName, spellName)
    sheep.guid, sheep.mobName, sheep.spellName = guid, mobName, spellName
    sheep.clickName, sheep.clickSpell = mobName, spellName
    local token = {}
    sheep.token = token
    Bind(FindUnit(guid))
    Layout()
    ApplyClick()
    C_Timer.After(LONGEST_SECONDS + FORGET_SLACK, function()
        if sheep.token == token then
            Forget()
        end
    end)
end

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    if button.mobName then
        GameTooltip:SetText("Click: " .. button.spellName .. " your focus again.", 1, 1, 1)
        GameTooltip:AddLine("With no focus, targets " .. button.mobName .. " by name, then goes back to your "
            .. "target.", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:SetText("Polymorph a mob, then click here to sheep it again.", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

-- The bar's sizes now, from its settings.
local function Sizes()
    local settings = MTF.db.polymorph
    local text = settings.textScale / 100
    local header = math.floor(HEADER * text + 0.5)
    local line = settings.height
    return {width = settings.width, header = header, line = line, icon = line - ICON_INSET,
        height = header + line + PADDING, text = text, alpha = settings.opacity / 100}
end

-- A font string at the text size: its template's own size, read once when
-- the font string is new, times the setting. Found in client (1.1.0): setting
-- the template again did not reset a size set before, so each slider step
-- multiplied the last size and the bar's label grew huge.
local function ScaleFont(text, scale)
    local base = text.mtfBaseFont
    if not base then
        local font, size, flags = text:GetFont()
        base = {font = font, size = size, flags = flags}
        text.mtfBaseFont = base
    end
    if base.font and type(base.size) == "number" then
        text:SetFont(base.font, base.size * scale, base.flags)
    end
end

-- The engine slot's regions, at the sizes of this build. Only here may MTF
-- touch what it hands to the engine (SetIcon, SetDurationBar, SetSpellName,
-- SetDurationText): afterwards each is the engine's, and a later call raised
-- "Attempt to access forbidden object from code tainted by an AddOn" in WTF
-- (found in client). So a new size or opacity rebuilds the slot. The engine's
-- duration bar ignored its parent's opacity in WTF, so it ignores it here on
-- purpose and carries the opacity in its color, its texts too.
local function SlotInitializer(size)
    return function(button)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", PADDING, -size.header)
        button:SetSize(size.width - PADDING * 2, size.line)
        button:SetMouseClickEnabled(false)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(size.icon, size.icon)
        icon:SetPoint("LEFT", 1, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local status = CreateFrame("StatusBar", nil, button)
        status:SetPoint("TOPLEFT", button, "TOPLEFT", size.icon + 4, 0)
        status:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        status:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        if type(status.SetIgnoreParentAlpha) == "function" then
            status:SetIgnoreParentAlpha(true)
        end
        status:SetStatusBarColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], size.alpha)
        local spellName = status:CreateFontString(nil, "OVERLAY", NAME_FONT)
        ScaleFont(spellName, size.text)
        spellName:SetPoint("LEFT", 4, 0)
        spellName:SetJustifyH("LEFT")
        spellName:SetAlpha(size.alpha)
        local timeLeft = status:CreateFontString(nil, "OVERLAY", NAME_FONT)
        ScaleFont(timeLeft, size.text)
        timeLeft:SetPoint("RIGHT", -4, 0)
        timeLeft:SetAlpha(size.alpha)
        button:SetIcon(icon)
        local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
        button:SetDurationBar(status, {direction = direction})
        button:SetSpellName(spellName)
        button:SetDurationText(timeLeft, {})
    end
end

-- The whole bar fades with its opacity setting. SetAlpha is no protected
-- action, so this applies at once, also in combat; the engine's duration bar
-- follows with the next build.
local function ApplyOpacity()
    bar:SetAlpha(MTF.db.polymorph.opacity / 100)
end

-- The bar's own regions at its size settings. The bar is no secure frame, so
-- this applies at once, also in combat.
local function ApplyLook()
    local size = Sizes()
    bar:SetSize(size.width, size.height)
    ScaleFont(bar.name, size.text)
    bar.name:SetWidth(size.width - PADDING * 2)
    bar.line:ClearAllPoints()
    bar.line:SetPoint("TOPLEFT", bar, "TOPLEFT", PADDING, -size.header)
    bar.line:SetSize(size.width - PADDING * 2, size.line)
    bar.placeholder:SetSize(size.icon, size.icon)
    ScaleFont(bar.label, size.text)
    bar.label:ClearAllPoints()
    bar.label:SetPoint("LEFT", bar.line, "LEFT", size.icon + 8, 0)
    return size
end

-- What the engine's slot was built for: a change rebuilds it.
local function BuildKey(size)
    return string.format("%d:%d:%d:%d", size.width, size.line, math.floor(size.text * 100 + 0.5),
        math.floor(size.alpha * 100 + 0.5))
end

-- Builds the bar at its size settings: the bar's own regions and a new
-- container (the old one lets its mob go and hides), bound again to the sheep
-- that is up. Out of combat only; a change in combat waits for the end of
-- combat. The secure holder's size and place are Dyre's Toolkit's.
local function BuildBar()
    if InCombatLockdown() then
        sheep.buildDirty = true
        return
    end
    sheep.buildDirty = false
    local size = ApplyLook()
    bar.builtKey = BuildKey(size)
    if bar.container then
        bar.container:SetUnit("none")
        bar.container:Hide()
    end
    local container = CreateFrame("AuraContainer", nil, bar, CONTAINER_TEMPLATE)
    container:SetPoint("TOPLEFT", bar, "TOPLEFT")
    container:SetSize(1, 1)
    container:AddAuraSlot("polymorph", AURA_FILTER, {
        candidateFilters = {includeSpellIDs = sheep.ids},
        initializeFrame = SlotInitializer(size),
    })
    bar.container = container
    bar.boundUnit = nil
    Bind(FindUnit(sheep.guid))
    ApplyOpacity()
end

local function CreateBar()
    holder = CreateFrame("Button", "MageToolsForeverPolymorph", UIParent, "SecureActionButtonTemplate")
    holder:RegisterForClicks("AnyUp", "AnyDown")
    holder:SetAttribute("useOnKeyDown", false)
    holder:SetScript("OnEnter", ShowTooltip)
    holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- The bar sits on the holder and takes no mouse, so clicks reach the holder.
    -- Not its child: a secure parent would stop it showing and hiding in combat.
    -- Centered on the holder, so it grows around its middle with it.
    bar = CreateFrame("Frame", "MageToolsForeverPolymorphBar", UIParent, "BackdropTemplate")
    bar:SetPoint("CENTER", holder, "CENTER")
    bar:EnableMouse(false)
    bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
        insets = {left = 2, right = 2, top = 2, bottom = 2}})
    bar:SetBackdropColor(BROWN[1], BROWN[2], BROWN[3], BROWN[4])
    bar:SetBackdropBorderColor(IDLE_BORDER[1], IDLE_BORDER[2], IDLE_BORDER[3])
    bar.name = bar:CreateFontString(nil, "OVERLAY", NAME_FONT)
    bar.name:SetPoint("TOPLEFT", PADDING, -4)
    bar.name:SetJustifyH("LEFT")
    -- Behind the engine's bar: a dim line with the icon and the spell's name.
    bar.line = bar:CreateTexture(nil, "BACKGROUND")
    bar.line:SetColorTexture(LINE_BACKGROUND[1], LINE_BACKGROUND[2], LINE_BACKGROUND[3], LINE_BACKGROUND[4])
    bar.placeholder = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar.placeholder:SetTexture(C_Spell.GetSpellTexture(POLYMORPH_IDS[1]))
    bar.placeholder:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.placeholder:SetDesaturated(true)
    bar.placeholder:SetAlpha(PLACEHOLDER_ALPHA)
    bar.placeholder:SetPoint("LEFT", bar.line, "LEFT", 1, 0)
    bar.label = bar:CreateFontString(nil, "BORDER", LABEL_FONT)
    bar.label:SetText(C_Spell.GetSpellName(POLYMORPH_IDS[1]) or "Polymorph")
    bar.boundUnit = nil
    MTF.polymorphBar = bar
end

-- The macro -----------------------------------------------------------------------
-- (author-approved, after the author's own): "! Polymorph" for your action
-- bars, once you know Polymorph. It focuses the hostile mob under the mouse
-- (or, out of combat, your target), marks it with the moon (with the mark
-- switch on), and sheeps your focus, so the macro, the bar's click, and the
-- moon agree on one mob. The /tm "!" never toggles the moon off.

local MACRO_NAME = "! Polymorph"

function MTF.PolymorphMacroBody()
    local spell = C_Spell.GetSpellName(POLYMORPH_IDS[1])
    if not spell then
        return nil
    end
    return "#showtooltip " .. spell .. "\n/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. MarkLine(MARK_FOCUS) .. "/use [@focus,exists,harm,nodead] " .. spell
end

-- Out of combat only; turning the macro off deletes it.
function MTF.ApplyPolymorphMacro()
    if InCombatLockdown() then
        sheep.macroDirty = true
        return
    end
    sheep.macroDirty = false
    if not MTF.CharacterMacrosAvailable() then
        return
    end
    local body = MTF.PolymorphMacroBody()
    if MTF.db.polymorph.macro and body and KnowsPolymorph() then
        MTF.WriteCharacterMacro(MACRO_NAME, body)
    elseif not MTF.db.polymorph.macro then
        MTF.DeleteCharacterMacro(MACRO_NAME)
    end
end

-- Casts --------------------------------------------------------------------------

local function GroupChannel()
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
end

-- At the start of a cast (author-approved), raid or party only, as the portal message.
local function AnnounceCast(targetName)
    local announce = MTF.db.announce
    local channel = GroupChannel()
    local now = GetTime()
    if not announce.polymorphGroup or not channel
        or (sheep.lastAnnounce and now - sheep.lastAnnounce < ANNOUNCE_REPEAT_SECONDS) then
        return
    end
    sheep.lastAnnounce = now
    local send = type(C_ChatInfo) == "table" and C_ChatInfo.SendChatMessage or SendChatMessage
    send(MTF.FormatAnnouncement(announce.polymorphGroupText, {T = targetName}), channel)
end

local function OnCastSent(target, castGUID, spellID)
    if MTF.IsSecret(spellID) or MTF.IsSecret(target) or MTF.IsSecret(castGUID)
        or type(target) ~= "string" or target == "" or not sheep.ids[spellID] then
        return
    end
    local unit = FindCastUnit(target)
    sheep.casts[castGUID] = {target = target, spellID = spellID, guid = unit and ReadGUID(unit)}
    sheep.lastCast = {spellID = spellID, target = target}
    if not MTF.db.polymorph.enabled then
        return
    end
    AnnounceCast(target)
    -- A pull's Polymorph starts out of combat and lands in it: set the click
    -- now, while the game still allows it.
    if not InCombatLockdown() then
        sheep.clickName, sheep.clickSpell = target, C_Spell.GetSpellName(spellID)
        sheep.casts[castGUID].setClick = true
        ApplyClick()
    end
end

local function OnCastSucceeded(castGUID)
    if MTF.IsSecret(castGUID) then
        return
    end
    local cast = sheep.casts[castGUID]
    sheep.casts = {}
    if not cast or not MTF.db.polymorph.enabled then
        return
    end
    local guid = cast.guid
    if not guid then
        local unit = FindCastUnit(cast.target)
        guid = unit and ReadGUID(unit)
    end
    -- A Polymorph cast on the mob under the mouse counts: mouseover checks the
    -- cast, though the bar never binds to it; the bar finds the mob when it
    -- becomes your focus, target, or a nameplate.
    local unit = FindUnit(guid)
    if not unit and guid and ReadGUID("mouseover") == guid then
        unit = "mouseover"
    end
    if not unit or not UnitCanAttack("player", unit) then
        return
    end
    Track(guid, cast.target, C_Spell.GetSpellName(cast.spellID))
end

local function Rebind()
    if sheep.guid then
        local unit = FindUnit(sheep.guid)
        if unit and IsDead(unit) then
            Forget()
        else
            Bind(unit)
        end
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, first, second, third)
    if event == "UNIT_SPELLCAST_SENT" then
        OnCastSent(first, second, third)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnCastSucceeded(first)
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not MTF.IsSecret(first) then
            local cast = sheep.casts[first]
            sheep.casts[first] = nil
            -- A cast that never landed gives the click back to the sheep that
            -- is up, or clears it.
            if cast and cast.setClick then
                sheep.clickName = sheep.mobName
                sheep.clickSpell = sheep.mobName and sheep.spellName or nil
                ApplyClick()
            end
        end
    elseif event == "UNIT_HEALTH" then
        -- By GUID: the death can come through any unit that shows the mob.
        if sheep.guid and ReadGUID(unit) == sheep.guid and IsDead(unit) then
            Forget()
        end
    elseif event == "SPELLS_CHANGED" then
        BuildSpellSet()
        if bar.container then
            bar.container:SetAuraSlotCandidateFilters("polymorph", {includeSpellIDs = sheep.ids})
        end
        ApplyClick()
        MTF.ApplyPolymorphMacro()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if sheep.macroDirty then
            MTF.ApplyPolymorphMacro()
        end
        if sheep.buildDirty then
            BuildBar()
        end
        if sheep.clickDirty then
            ApplyClick()
        end
    else
        if event == "PLAYER_TARGET_CHANGED" and bar.boundUnit == "target" then
            bar.container:UpdateAllAuras()
        end
        Rebind()
    end
end)

function MTF.RefreshPolymorph()
    if not sheep.available then
        return
    end
    Layout()
    ApplyClick()
    MTF.ApplyPolymorphMacro()
end

-- A setting change: the look follows at once, and one rebuild runs after the
-- slider rests (out of combat, or when combat ends).
local function ScheduleBuild()
    local token = {}
    sheep.buildToken = token
    C_Timer.After(BUILD_DELAY, function()
        if sheep.buildToken == token then
            BuildBar()
        end
    end)
end

-- The holder is a Dyre's Toolkit widget: the toolkit places, drags, snaps,
-- outlines, saves, and sizes it (its frame size from the bar's settings,
-- through measure), with Bar size as its scale and the sliders on the
-- Polymorph page. Existing saves carry over: the bar line's height is saved
-- as "height", which the toolkit reserves for a frame height, so the setting
-- is named barHeight. Its mouse is MTF's: clicks only with a sheep to click
-- or while unlocked (ApplyClick).
local function CreateWidget()
    local specs = {}
    for _, spec in ipairs(MTF.POLYMORPH_SIZE_SPECS) do
        specs[spec.key] = spec
    end
    local function Range(spec, label)
        return {min = spec.min, max = spec.max, step = spec.step, default = spec.default, label = label,
            percent = spec.percent}
    end
    local size = Sizes()
    MTF.polymorphWidget = MTF.toolkit.CreateWidget({
        addon = "MageToolsForever", key = "polymorph", title = "Polymorph", frame = holder,
        store = MTF.db.polymorph, width = size.width, height = size.height, point = DEFAULT_POINT,
        mouse = "client", keys = {barHeight = "height"},
        sizes = {
            scale = {min = MTF.SCALE_MIN, max = MTF.SCALE_MAX, step = MTF.SCALE_STEP, default = MTF.DEFAULT_SCALE},
            width = Range(specs.width, "Bar width"),
            barHeight = Range(specs.height, "Bar height"),
            textScale = Range(specs.textScale, "Text size"),
            opacity = {min = MTF.POLYMORPH_OPACITY_MIN, max = MTF.POLYMORPH_OPACITY_MAX,
                step = MTF.POLYMORPH_OPACITY_STEP, default = MTF.DEFAULT_POLYMORPH_OPACITY},
        },
        sizeOrder = {"scale", "width", "barHeight", "textScale"},
        -- Reset size (John-approved): the bar's own sizes; Bar size and Opacity stay.
        resetSizes = {"width", "barHeight", "textScale"},
        measure = function()
            local current = Sizes()
            return current.width, current.height
        end,
        onLayout = function(_, _, _, scale)
            bar:SetScale(scale)
            local current = ApplyLook()
            if not bar.container then
                BuildBar()
            elseif BuildKey(current) ~= bar.builtKey then
                ScheduleBuild()
            end
        end,
        onOpacity = function()
            ApplyOpacity()
            if bar.container and BuildKey(Sizes()) ~= bar.builtKey then
                ScheduleBuild()
            end
        end,
    })
end

function MTF.InitializePolymorph()
    if not HasAuraContainer() then
        MTF.Report("The Polymorph bar stays off: this client lacks " .. CONTAINER_TEMPLATE .. ".")
        return
    end
    BuildSpellSet()
    CreateBar()
    CreateWidget()
    sheep.available = true
    for _, event in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "SPELLS_CHANGED", "UNIT_HEALTH"}) do
        events:RegisterEvent(event)
    end
    for _, event in ipairs({"UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED"}) do
        events:RegisterUnitEvent(event, "player")
    end
    Layout()
    ApplyClick()
    MTF.ApplyPolymorphMacro()
end

-- /mtf debug_polymorph: the IDs, the tracked mob, and the click.
function MTF.ReportPolymorphDebug()
    MTF.Report(string.format("debug_polymorph available=%s known=%s", tostring(sheep.available),
        tostring(KnowsPolymorph())))
    if not sheep.available then
        return
    end
    local ids = {}
    for id in pairs(sheep.ids) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    MTF.Report("debug_polymorph ids=" .. table.concat(ids, ","))
    local last = sheep.lastCast
    if last then
        MTF.Report(string.format("debug_polymorph lastCast spell=%d target=%s", last.spellID, last.target))
    end
    MTF.Report(string.format("debug_polymorph mob=%s unit=%s moon=%s", tostring(sheep.mobName),
        tostring(bar.boundUnit), MTF.db.polymorph.mark and "from the macro and the click" or "off"))
    MTF.Report(string.format("debug_polymorph click shown=%s type=%s macro=%s", tostring(holder:IsShown()),
        tostring(holder:GetAttribute("type1")), tostring(holder:GetAttribute("macrotext1")):gsub("\n", " | ")))
end
