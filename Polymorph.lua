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
-- On cast, MTF can tell the group (Announce). When the cast succeeds, it marks
-- the mob with the moon (author-approved). The combat log is closed to
-- AddOns, so a resist cannot be seen; a successful cast counts as landed.
--
-- Clicking the bar re-sheeps the mob: a secure macro targets it by name,
-- casts Polymorph, and goes back to your target. Secure attributes change only
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
local AURA_FILTER = "HARMFUL|PLAYER"
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local MAX_NAMEPLATE_UNITS = 40
local ANNOUNCE_REPEAT_SECONDS = 3

-- WTF's Bars theme: the name line, then a bar line with an icon.
local WIDTH = 200
local HEADER = 18
local LINE = 16
local ICON = 14
local PADDING = 6
local HEIGHT = HEADER + LINE + PADDING
local BROWN = {0.28, 0.16, 0.07, 0.85}
local IDLE_BORDER = {0.45, 0.35, 0.2}
local LINE_BACKGROUND = {0.1, 0.1, 0.1, 0.6}
local BAR_COLOR = {0.75, 0.45, 0.95}
local PLACEHOLDER_ALPHA = 0.3
local DEFAULT_POINT = {"CENTER", "CENTER", -260, 60}
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

-- The unit showing this mob now: its nameplate, else target or focus. Not
-- mouseover: it changes with the pointer and has no event MTF rebinds on.
local function FindUnit(guid)
    if not guid then
        return nil
    end
    for index = 1, MAX_NAMEPLATE_UNITS do
        local unit = "nameplate" .. index
        if UnitExists(unit) and ReadGUID(unit) == guid then
            return unit
        end
    end
    for _, unit in ipairs({"target", "focus"}) do
        if ReadGUID(unit) == guid then
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
    if bar.boundUnit == wanted then
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
    bar.mover:SetShown(sample)
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
    -- The holder is secure: it changes only here, out of combat. A secure
    -- change in combat is blocked, and in client a Polymorph that landed in
    -- combat once rescaled it there, after which its clicks failed. The bar
    -- scales with it, so they never drift apart.
    holder:SetScale(settings.scale / 100)
    bar:SetScale(settings.scale / 100)
    local name, spell = sheep.clickName, sheep.clickSpell
    if name and spell then
        -- A missing mob leaves no target, so nothing else gets sheeped.
        holder:SetAttribute("type1", "macro")
        holder:SetAttribute("macrotext1", "/cleartarget\n/targetexact " .. name .. "\n/cast [@target,harm,nodead] "
            .. spell .. "\n/targetlasttarget")
    else
        holder:SetAttribute("type1", nil)
        holder:SetAttribute("macrotext1", nil)
    end
    holder.mobName, holder.spellName = name, spell
    -- Shown while unlocked even before you learn Polymorph, so it can be placed.
    holder:SetShown(settings.enabled and (KnowsPolymorph() or not MTF.db.locked))
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
        GameTooltip:SetText("Click: " .. button.spellName .. " " .. button.mobName .. " again.", 1, 1, 1)
        GameTooltip:AddLine("Targets it by name, then goes back to your target.", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:SetText("Polymorph a mob, then click here to sheep it again.", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

-- Dragging and snapping: Layout.lua. The holder moves; the bar rides on it.
local function StartDrag()
    MTF.BeginDrag(holder)
end

local function StopDrag()
    MTF.EndDrag(holder)
end

local function Place()
    local position = MTF.db.polymorph.position
    holder:ClearAllPoints()
    if position then
        holder:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        holder:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

-- The engine slot's regions; only here may MTF place the engine's button.
local function InitializeSlot(button)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", bar, "TOPLEFT", PADDING, -HEADER)
    button:SetSize(WIDTH - PADDING * 2, LINE)
    button:SetMouseClickEnabled(false)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", 1, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local status = CreateFrame("StatusBar", nil, button)
    status:SetPoint("TOPLEFT", button, "TOPLEFT", ICON + 4, 0)
    status:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    status:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    status:SetStatusBarColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3])
    local spellName = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellName:SetPoint("LEFT", 4, 0)
    spellName:SetJustifyH("LEFT")
    local timeLeft = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeLeft:SetPoint("RIGHT", -4, 0)
    button:SetIcon(icon)
    local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
    button:SetDurationBar(status, {direction = direction})
    button:SetSpellName(spellName)
    button:SetDurationText(timeLeft, {})
end

local function CreateBar()
    holder = CreateFrame("Button", "MageToolsForeverPolymorph", UIParent, "SecureActionButtonTemplate")
    holder:SetSize(WIDTH, HEIGHT)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:RegisterForClicks("AnyUp", "AnyDown")
    holder:SetAttribute("useOnKeyDown", false)
    holder:RegisterForDrag("LeftButton")
    holder:SetScript("OnDragStart", StartDrag)
    holder:SetScript("OnDragStop", StopDrag)
    MTF.RegisterMovable(holder, function(position) MTF.db.polymorph.position = position end)
    holder:SetScript("OnEnter", ShowTooltip)
    holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- The bar sits on the holder and takes no mouse, so clicks reach the holder.
    bar = CreateFrame("Frame", "MageToolsForeverPolymorphBar", UIParent, "BackdropTemplate")
    bar:SetSize(WIDTH, HEIGHT)
    bar:SetPoint("TOPLEFT", holder, "TOPLEFT")
    bar:EnableMouse(false)
    bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
        insets = {left = 2, right = 2, top = 2, bottom = 2}})
    bar:SetBackdropColor(BROWN[1], BROWN[2], BROWN[3], BROWN[4])
    bar:SetBackdropBorderColor(IDLE_BORDER[1], IDLE_BORDER[2], IDLE_BORDER[3])
    bar.name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.name:SetPoint("TOPLEFT", PADDING, -4)
    bar.name:SetWidth(WIDTH - PADDING * 2)
    bar.name:SetJustifyH("LEFT")
    -- Behind the engine's bar: a dim line with the icon and the spell's name.
    local line = bar:CreateTexture(nil, "BACKGROUND")
    line:SetPoint("TOPLEFT", bar, "TOPLEFT", PADDING, -HEADER)
    line:SetSize(WIDTH - PADDING * 2, LINE)
    line:SetColorTexture(LINE_BACKGROUND[1], LINE_BACKGROUND[2], LINE_BACKGROUND[3], LINE_BACKGROUND[4])
    local placeholder = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    placeholder:SetTexture(C_Spell.GetSpellTexture(POLYMORPH_IDS[1]))
    placeholder:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    placeholder:SetDesaturated(true)
    placeholder:SetAlpha(PLACEHOLDER_ALPHA)
    placeholder:SetSize(ICON, ICON)
    placeholder:SetPoint("LEFT", line, "LEFT", 1, 0)
    local label = bar:CreateFontString(nil, "BORDER", "GameFontDisableSmall")
    label:SetPoint("LEFT", line, "LEFT", ICON + 8, 0)
    label:SetText(C_Spell.GetSpellName(POLYMORPH_IDS[1]) or "Polymorph")
    local container = CreateFrame("AuraContainer", nil, bar, CONTAINER_TEMPLATE)
    container:SetPoint("TOPLEFT", bar, "TOPLEFT")
    container:SetSize(1, 1)
    container:AddAuraSlot("polymorph", AURA_FILTER, {
        candidateFilters = {includeSpellIDs = sheep.ids},
        initializeFrame = InitializeSlot,
    })
    bar.container = container
    bar.boundUnit = nil
    bar.mover = MTF.CreateMover(bar)
    MTF.polymorphBar = bar
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

-- The unit to mark: your target or focus when it is this mob (as TankHelper
-- marks your target), else the unit that shows it. SetRaidTarget toggles: a
-- unit that already has the marker loses it (the pinned /tm code's "!" prefix
-- exists to skip that). GetRaidTargetIndex returns a secret to AddOn code in
-- combat (pinned RaidMarkersDocumentation: SecretReturns), so MTF cannot
-- always ask. It skips the mark when the index is readable and already
-- equal, or, when it is not, when it marked this mob with it before.
local function Mark(guid, unit)
    if not MTF.db.polymorph.mark or type(SetRaidTarget) ~= "function" then
        return
    end
    for _, candidate in ipairs({"target", "focus"}) do
        if ReadGUID(candidate) == guid then
            unit = candidate
            break
        end
    end
    local index = GetRaidTargetIndex(unit)
    local unreadable = MTF.IsSecret(index)
    if (not unreadable and index == MOON) or (unreadable and sheep.markedGUID == guid) then
        sheep.markedGUID = guid
        return
    end
    SetRaidTarget(unit, MOON)
    sheep.markedGUID = guid
    sheep.lastMark = unit .. (unreadable and " (marker unreadable)" or "")
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
    local unit = FindUnit(guid)
    if not unit or not UnitCanAttack("player", unit) then
        return
    end
    Mark(guid, unit)
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
        if sheep.guid and bar.boundUnit == unit and IsDead(unit) then
            Forget()
        end
    elseif event == "SPELLS_CHANGED" then
        BuildSpellSet()
        bar.container:SetAuraSlotCandidateFilters("polymorph", {includeSpellIDs = sheep.ids})
        ApplyClick()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if sheep.placeDirty then
            sheep.placeDirty = false
            Place()
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
end

function MTF.ResetPolymorphPosition()
    MTF.db.polymorph.position = nil
    if not sheep.available then
        return
    end
    if InCombatLockdown() then
        sheep.placeDirty = true
        return
    end
    Place()
end

function MTF.InitializePolymorph()
    if not HasAuraContainer() then
        MTF.Report("The Polymorph bar stays off: this client lacks " .. CONTAINER_TEMPLATE .. ".")
        return
    end
    BuildSpellSet()
    CreateBar()
    Place()
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
end

-- /mtf debug_polymorph: the IDs, the tracked mob, the click, and the marker.
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
    MTF.Report(string.format("debug_polymorph mob=%s unit=%s marked=%s", tostring(sheep.mobName),
        tostring(bar.boundUnit), tostring(sheep.lastMark)))
    MTF.Report(string.format("debug_polymorph click shown=%s type=%s macro=%s", tostring(holder:IsShown()),
        tostring(holder:GetAttribute("type1")), tostring(holder:GetAttribute("macrotext1")):gsub("\n", " | ")))
end
