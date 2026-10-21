local _, MTF = ...

-- Buff reminders (author-approved): one icon per buff, shown only while the
-- buff is missing, with a pulsing gold border that draws the eye. Each icon
-- moves and resizes on its own while frames are unlocked (drag to move, scroll
-- to resize), then locks with everything else. Icons are magnetic
-- (author-approved): one dropped near another snaps beside it, 20 apart and
-- aligned; Shift-dragging an icon moves every icon snapped to it.
--
-- Clicking an icon casts the missing buff (author-approved): Arcane Intellect
-- on you first, then the first group member in range who lacks it, so each
-- click moves down the list as the buff lands; Arcane Brilliance instead when
-- two or more lack it, you know it, and you carry Arcane Powder. Armor and
-- Dampen or Amplify Magic recast the last one you used, else your best.
--
-- Aura APIs refuse AddOn code in combat on Forever, so MTF checks only out of
-- combat. The icons are secure buttons, which change only out of combat, so
-- they sit in a holder the game hides for combat with a state driver: a
-- reminder is for between pulls.

-- Classic IDs; a buff counts by name, so every rank does. Arcane Intellect
-- also counts Arcane Brilliance, and checks your group's mana users when the
-- group option is on. Any armor counts for Armor. prefer lists what a click
-- casts, best first, until you cast one yourself.
MTF.REMINDERS = {
    {key = "intellect", label = "Arcane Intellect", on = true, group = true,
        spells = {1459, 1460, 1461, 10156, 10157, 23028}, prefer = {1459}, groupSpell = 23028, reagent = 17020},
    {key = "armor", label = "Armor (Frost, Ice, or Mage Armor)", on = true,
        spells = {168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783}, prefer = {6117, 7302, 168}},
    {key = "dampen", label = "Dampen or Amplify Magic", on = false,
        spells = {604, 8450, 8451, 10173, 10174, 1008, 8455, 10169, 10170}, prefer = {604, 1008}},
}
MTF.REMINDER_SCALE_MIN = 50
MTF.REMINDER_SCALE_MAX = 200
MTF.REMINDER_SCALE_STEP = 10
MTF.DEFAULT_REMINDER_SCALE = 100

local ICON_SIZE = 40
-- The default row's gap, the snapped gap.
local ICON_GAP = 20
local BORDER = 3
local GOLD = {1, 0.82, 0}
local PULSE_SECONDS = 0.6
local PULSE_LOW_ALPHA = 0.15
local DEFAULT_Y = 180
local COMBAT_DRIVER = "[combat] hide; show"
-- Classes without mana need no Arcane Intellect.
local NO_MANA = {WARRIOR = true, ROGUE = true}
local MAX_PARTY = 4
local MAX_RAID = 40
local BRILLIANCE_AT = 2

local reminders = {icons = {}, spellKeys = {}}
local holder

local function Knows(id)
    return C_SpellBook.IsSpellKnown(id) == true
end

local function Known(reminder)
    for _, id in ipairs(reminder.spells) do
        if Knows(id) then
            return true
        end
    end
    return false
end

-- Spell names you know for a reminder.
local function KnownNames(reminder)
    local names = {}
    for _, id in ipairs(reminder.spells) do
        local name = C_Spell.GetSpellName(id)
        if name and Knows(id) then
            names[name] = true
        end
    end
    return names
end

local function BestTexture(reminder)
    for index = #reminder.spells, 1, -1 do
        local id = reminder.spells[index]
        if Knows(id) then
            return C_Spell.GetSpellTexture(id)
        end
    end
    return C_Spell.GetSpellTexture(reminder.spells[1])
end

-- Out of combat only. A secret answer counts as buffed: MTF cannot tell.
local function HasBuff(unit, reminder)
    for _, id in ipairs(reminder.spells) do
        local name = C_Spell.GetSpellName(id)
        if name then
            local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
            if aura ~= nil then
                return true
            end
        end
    end
    return false
end

local function Usable(unit)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then
        return false
    end
    local dead, connected = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
    if MTF.IsSecret(dead) or dead == true or MTF.IsSecret(connected) or connected == false then
        return false
    end
    -- Out of sight, a unit's buffs may not be known.
    local visible = UnitIsVisible(unit)
    if MTF.IsSecret(visible) or visible == false then
        return false
    end
    local _, class = UnitClass(unit)
    return not NO_MANA[class]
end

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for index = 1, MAX_RAID do
            units[#units + 1] = "raid" .. index
        end
    elseif IsInGroup() then
        for index = 1, MAX_PARTY do
            units[#units + 1] = "party" .. index
        end
    end
    return units
end

-- Who lacks the buff, as {unit, name}: you first, then group members.
local function Missing(reminder)
    local missing = {}
    if not HasBuff("player", reminder) then
        missing[#missing + 1] = {unit = "player", name = "you"}
    end
    if reminder.group and MTF.db.reminders.group then
        for _, unit in ipairs(GroupUnits()) do
            if Usable(unit) and not HasBuff(unit, reminder) then
                local name = UnitName(unit)
                missing[#missing + 1] = {unit = unit, name = (not MTF.IsSecret(name) and name) or unit}
            end
        end
    end
    return missing
end

local function MissingNames(missing)
    local names = {}
    for _, entry in ipairs(missing) do
        names[#names + 1] = entry.name
    end
    return names
end

-- Click target -----------------------------------------------------------------

local function InRange(spell, unit)
    if unit == "player" or type(C_Spell.IsSpellInRange) ~= "function" then
        return true
    end
    local inRange = C_Spell.IsSpellInRange(spell, unit)
    return MTF.IsSecret(inRange) or inRange ~= false
end

-- The spell a click casts on the self-buffs: the last one you cast, else
-- your best known.
local function SelfSpell(reminder)
    local last = MTF.db.reminders.last[reminder.key]
    if last and KnownNames(reminder)[last] then
        return last
    end
    for _, id in ipairs(reminder.prefer) do
        if Knows(id) then
            return C_Spell.GetSpellName(id)
        end
    end
end

-- What a click does now: {spell, unit, name}, or nil.
local function ClickAction(reminder, missing)
    if #missing == 0 then
        return nil
    end
    if not reminder.groupSpell then
        local spell = SelfSpell(reminder)
        return spell and {spell = spell, unit = "player", name = "you"}
    end
    local brilliance = C_Spell.GetSpellName(reminder.groupSpell)
    if #missing >= BRILLIANCE_AT and brilliance and Knows(reminder.groupSpell)
        and (C_Item.GetItemCount(reminder.reagent) or 0) > 0 then
        for _, entry in ipairs(missing) do
            if InRange(brilliance, entry.unit) then
                return {spell = brilliance, unit = entry.unit, name = "your group", group = true}
            end
        end
    end
    local intellect = C_Spell.GetSpellName(reminder.prefer[1])
    if not intellect then
        return nil
    end
    for _, entry in ipairs(missing) do
        if InRange(intellect, entry.unit) then
            return {spell = intellect, unit = entry.unit, name = entry.name}
        end
    end
    return {spell = intellect, unit = missing[1].unit, name = missing[1].name}
end

-- Out of combat only.
local function ApplyClick(icon, action)
    icon.action = action
    icon:SetAttribute("type1", action and "spell" or nil)
    icon:SetAttribute("spell1", action and action.spell or nil)
    icon:SetAttribute("unit1", action and action.unit or nil)
end

-- Display ----------------------------------------------------------------------

local function Pulse(icon, on)
    if on and not icon.pulse:IsPlaying() then
        icon.pulse:Play()
    elseif not on then
        icon.pulse:Stop()
    end
end

local function ShowIcon(icon, shown, count)
    icon.count:SetText(count and count > 1 and count or "")
    icon:SetShown(shown)
    Pulse(icon, shown)
end

function MTF.RefreshReminders()
    if not reminders.ready then
        return
    end
    -- Secure icons change only out of combat; the holder hides them for combat.
    if InCombatLockdown() then
        reminders.dirty = true
        return
    end
    reminders.dirty = false
    local settings = MTF.db.reminders
    local unlocked = not MTF.db.locked
    local canCheck = settings.enabled and UnitIsDeadOrGhost("player") ~= true
    local aside = MTF.RemindersStandAside()
    for _, reminder in ipairs(MTF.REMINDERS) do
        local icon = reminders.icons[reminder.key]
        local saved = settings.icons[reminder.key]
        icon.texture:SetTexture(BestTexture(reminder))
        icon:EnableMouseWheel(unlocked)
        local wanted = settings.enabled and settings.spells[reminder.key] and not aside
        icon.missing = nil
        if unlocked then
            -- Dragging must not cast.
            ApplyClick(icon, nil)
            ShowIcon(icon, wanted, nil)
        elseif wanted and canCheck and Known(reminder) then
            local missing = Missing(reminder)
            icon.missing = MissingNames(missing)
            ApplyClick(icon, ClickAction(reminder, missing))
            ShowIcon(icon, #missing > 0, #missing)
        else
            ApplyClick(icon, nil)
            ShowIcon(icon, false)
        end
    end
end

local function DefaultPoint(index)
    local offset = (index - (#MTF.REMINDERS + 1) / 2) * (ICON_SIZE + ICON_GAP)
    return {point = "CENTER", relativePoint = "CENTER", x = offset, y = DEFAULT_Y}
end

-- /mtf reset: every icon back to its own size (the toolkit puts each back in
-- its place, after combat when needed).
function MTF.ResetRemindersSize()
    for _, reminder in ipairs(MTF.REMINDERS) do
        local icon = reminders.icons[reminder.key]
        if icon then
            icon:ResetSize()
        end
    end
end

-- Each icon is a Dyre's Toolkit widget: the toolkit places, drags, snaps,
-- sizes from the center, and saves it. While unlocked the mouse wheel sizes
-- it in 10% steps.
local function Resize(icon, delta)
    if MTF.db.locked or InCombatLockdown() then
        return
    end
    local step = delta > 0 and MTF.REMINDER_SCALE_STEP or -MTF.REMINDER_SCALE_STEP
    icon:SetSetting("scale", icon:GetSetting("scale") + step)
end

local function ShowTooltip(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetText(icon.label, GOLD[1], GOLD[2], GOLD[3])
    if not MTF.db.locked then
        GameTooltip:AddLine("Drag to move; drop near another to snap; Shift-drag to move a snapped group; "
            .. "scroll to resize.", 1, 1, 1, true)
    else
        if icon.missing and #icon.missing > 0 then
            GameTooltip:AddLine("Missing: " .. table.concat(icon.missing, ", "), 1, 1, 1, true)
        end
        local action = icon.action
        if action then
            local whom = action.group and "" or (" on " .. action.name)
            GameTooltip:AddLine("Click: " .. action.spell .. whom .. ".", 0.7, 0.7, 0.7, true)
        end
    end
    GameTooltip:Show()
end

local function CreateIcon(reminder, index)
    local icon = CreateFrame("Button", "MageToolsForeverReminder_" .. reminder.key, holder,
        "SecureActionButtonTemplate")
    icon.key, icon.label = reminder.key, reminder.label
    icon:RegisterForClicks("AnyUp", "AnyDown")
    icon:SetAttribute("useOnKeyDown", false)
    icon:SetScript("OnMouseWheel", Resize)
    icon:SetScript("OnEnter", ShowTooltip)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)
    -- The attention border: a solid gold edge that pulses.
    local glow = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    glow:SetPoint("TOPLEFT", -BORDER - 1, BORDER + 1)
    glow:SetPoint("BOTTOMRIGHT", BORDER + 1, -BORDER - 1)
    glow:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BORDER})
    glow:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    glow:EnableMouse(false)
    icon.glow = glow
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PULSE_LOW_ALPHA)
    fade:SetDuration(PULSE_SECONDS)
    icon.pulse = pulse
    icon:Hide()
    -- Clicks cast the missing buff, so it takes them also while locked; secure,
    -- so the toolkit changes it only out of combat.
    MTF.toolkit.CreateWidget({
        addon = "MageToolsForever", key = "reminder_" .. reminder.key, title = reminder.label, frame = icon,
        store = MTF.db.reminders.icons[reminder.key], width = ICON_SIZE, height = ICON_SIZE,
        point = DefaultPoint(index), mouse = "always",
        hint = reminder.label .. " · drag to move · scroll to resize · /dyre lock when done",
        sizes = {scale = {min = MTF.REMINDER_SCALE_MIN, max = MTF.REMINDER_SCALE_MAX, step = MTF.REMINDER_SCALE_STEP,
            default = MTF.DEFAULT_REMINDER_SCALE}},
    })
    return icon
end

-- The armor or Dampen/Amplify you cast is what a click recasts.
local function RememberCast(spellID)
    local key = not MTF.IsSecret(spellID) and reminders.spellKeys[spellID]
    if key then
        MTF.db.reminders.last[key] = C_Spell.GetSpellName(spellID)
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        RememberCast(spellID)
        return
    end
    if InCombatLockdown() then
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if reminders.driverPending then
            reminders.driverPending = false
            RegisterStateDriver(holder, "visibility", COMBAT_DRIVER)
        end
    end
    MTF.RefreshReminders()
end)

function MTF.InitializeReminders()
    if type(RegisterStateDriver) ~= "function" then
        MTF.Report("The buff reminders stay off: this client lacks RegisterStateDriver.")
        return
    end
    for _, reminder in ipairs(MTF.REMINDERS) do
        if not reminder.groupSpell then
            for _, id in ipairs(reminder.spells) do
                reminders.spellKeys[id] = reminder.key
            end
        end
    end
    holder = CreateFrame("Frame", "MageToolsForeverReminders", UIParent)
    holder:SetAllPoints(UIParent)
    holder:EnableMouse(false)
    for index, reminder in ipairs(MTF.REMINDERS) do
        reminders.icons[reminder.key] = CreateIcon(reminder, index)
    end
    reminders.ready = true
    for _, event in ipairs({"UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_DELAYED"}) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    -- After a reload in combat the driver waits for combat to end.
    if InCombatLockdown() then
        reminders.dirty = true
        reminders.driverPending = true
        return
    end
    RegisterStateDriver(holder, "visibility", COMBAT_DRIVER)
    MTF.RefreshReminders()
end

-- /mtf debug_reminders: each reminder, whether you know it, who lacks it, and the click.
function MTF.ReportRemindersDebug()
    for _, reminder in ipairs(MTF.REMINDERS) do
        local icon = reminders.icons[reminder.key]
        local missing = "not checked in combat"
        if not InCombatLockdown() then
            missing = table.concat(MissingNames(Missing(reminder)), ",")
        end
        local action = icon and icon.action
        MTF.Report(string.format("debug_reminders %s on=%s known=%s shown=%s missing=%s click=%s", reminder.key,
            tostring(MTF.db.reminders.spells[reminder.key]), tostring(Known(reminder)),
            tostring(icon and icon:IsShown()), missing,
            action and (action.spell .. "@" .. action.unit) or "none"))
    end
end

function MTF.SanitizeReminderScale(value)
    if type(value) ~= "number" or value ~= math.floor(value) then
        return MTF.DEFAULT_REMINDER_SCALE
    end
    local stepped = math.floor(value / MTF.REMINDER_SCALE_STEP + 0.5) * MTF.REMINDER_SCALE_STEP
    return math.max(MTF.REMINDER_SCALE_MIN, math.min(MTF.REMINDER_SCALE_MAX, stepped))
end
