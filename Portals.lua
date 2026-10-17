local _, MTF = ...

-- Portals: a small movable bar with a button for each teleport and portal you
-- know, teleports first, and the runes you carry for each (author-approved,
-- after PortalMage). The count is display only: the author's Mage uses legacy
-- talents that make portals free of reagents, so MTF never blocks a cast for
-- a rune count of zero; the game decides. The buttons are secure, so they
-- work in combat, but which spells they hold changes only out of combat.
-- When a portal opens, MTF can tell your group, and a teleport can emote
-- (Announce).

-- Classic IDs and the city each one goes to.
local TELEPORTS = {
    {spell = 3561, city = "Stormwind"},
    {spell = 3562, city = "Ironforge"},
    {spell = 3565, city = "Darnassus"},
    {spell = 3567, city = "Orgrimmar"},
    {spell = 3563, city = "Undercity"},
    {spell = 3566, city = "Thunder Bluff"},
}
local PORTALS = {
    {spell = 10059, city = "Stormwind"},
    {spell = 11416, city = "Ironforge"},
    {spell = 11419, city = "Darnassus"},
    {spell = 11417, city = "Orgrimmar"},
    {spell = 11418, city = "Undercity"},
    {spell = 11420, city = "Thunder Bluff"},
}
local RUNE_OF_TELEPORTATION = 17031
local RUNE_OF_PORTALS = 17032

local BUTTON_SIZE = 36
local BUTTON_GAP = 6
local PADDING = 6
local GOLD = {1, 0.82, 0}
local BROWN = {0.28, 0.16, 0.07, 0.85}
local DEFAULT_POINT = {"CENTER", "CENTER", 260, -190}
local MAX_BUTTONS = #TELEPORTS + #PORTALS

local portals = {pending = false, buttons = {}, names = {}, teleports = {}, lastAnnounce = nil}
local bar

local function Known(spellID)
    return C_SpellBook.IsSpellKnown(spellID) == true
end

local function Carried(itemID)
    return C_Item.GetItemCount(itemID) or 0
end

-- The spells you know, teleports first, each with its rune.
local function KnownSpells()
    local known = {}
    for _, group in ipairs({{TELEPORTS, RUNE_OF_TELEPORTATION}, {PORTALS, RUNE_OF_PORTALS}}) do
        for _, entry in ipairs(group[1]) do
            if Known(entry.spell) then
                known[#known + 1] = {spell = entry.spell, city = entry.city, rune = group[2]}
            end
        end
    end
    return known
end

local function ShowTooltip(button)
    if not button.entry then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(C_Spell.GetSpellName(button.entry.spell) or button.entry.city, GOLD[1], GOLD[2], GOLD[3])
    local rune = C_Item.GetItemInfo(button.entry.rune)
    GameTooltip:AddLine(string.format("%s carried: %d", rune or "Runes", Carried(button.entry.rune)), 1, 1, 1, true)
    GameTooltip:Show()
end

-- Out of combat only: which spells the buttons hold, and the bar's size.
local function ApplySpells()
    if InCombatLockdown() then
        portals.pending = true
        return
    end
    portals.pending = false
    local known = KnownSpells()
    for index, button in ipairs(portals.buttons) do
        local entry = known[index]
        button.entry = entry
        button:SetAttribute("type1", entry and "spell" or nil)
        button:SetAttribute("spell1", entry and entry.spell or nil)
        if entry then
            button.icon:SetTexture(C_Spell.GetSpellTexture(entry.spell))
            button:Show()
        else
            button:Hide()
        end
    end
    local count = math.max(1, #known)
    bar:SetSize(PADDING * 2 + BUTTON_SIZE * count + BUTTON_GAP * (count - 1), PADDING * 2 + BUTTON_SIZE)
    bar:SetScale(MTF.db.portals.scale / 100)
    -- Shown while unlocked even with nothing known, so it can be placed.
    if MTF.db.portals.enabled and (#known > 0 or not MTF.db.locked) then
        bar:Show()
    else
        bar:Hide()
    end
end

-- Rune counts change with your bags, also in combat: plain text.
local function UpdateCounts()
    for _, button in ipairs(portals.buttons) do
        if button.entry then
            button.count:SetText(Carried(button.entry.rune))
        end
    end
end

function MTF.RefreshPortals()
    if not bar then
        return
    end
    bar.mover:SetShown(not MTF.db.locked)
    ApplySpells()
    UpdateCounts()
end

local function PlaceBar()
    local position = MTF.db.portals.position
    bar:ClearAllPoints()
    if position then
        bar:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        bar:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

function MTF.ResetPortalsPosition()
    MTF.db.portals.position = nil
    if not bar then
        return
    end
    if InCombatLockdown() then
        portals.resetPending = true
        return
    end
    PlaceBar()
end

local function StartDrag()
    if MTF.db.locked or InCombatLockdown() then
        return
    end
    bar:StartMoving()
end

local function StopDrag()
    bar:StopMovingOrSizing()
    local point, _, relativePoint, x, y = bar:GetPoint()
    MTF.db.portals.position = {point = point, relativePoint = relativePoint, x = x, y = y}
end

local function CreateButton(index)
    local button = CreateFrame("Button", "MageToolsForeverPortal" .. index, bar, "SecureActionButtonTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint("LEFT", bar, "LEFT", PADDING + (index - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10})
    border:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", StartDrag)
    button:SetScript("OnDragStop", StopDrag)
    button:Hide()
    return button
end

-- Announce ----------------------------------------------------------------------
-- A portal you open is told to your raid or party (author-approved), never to
-- Say: the game blocks Say from AddOns outdoors outside a key press or click.
-- A cast is announced once.

local ANNOUNCE_REPEAT_SECONDS = 5
-- The game blocks emotes from AddOns outside a key press or click, so the
-- teleport emote waits for your next one, as WTF's emotes do; a loading
-- screen comes first, so it waits longer than WTF's.
local EMOTE_INPUT_WAIT = 60

local function SendChat(message, chatType)
    local send = type(C_ChatInfo) == "table" and C_ChatInfo.SendChatMessage or SendChatMessage
    send(message, chatType)
end

-- Your full name, "Dyre Smith", as %T is everywhere else.
local function PlayerName()
    local first, last = UnitName("player")
    if type(last) == "string" and last ~= "" then
        return first .. " " .. last
    end
    return first
end

local function EmoteTeleport(entry)
    local announce = MTF.db.announce
    if not announce.teleportEmote then
        return
    end
    local castAt = GetTime()
    MTF.RunOnNextInput(function()
        if GetTime() - castAt <= EMOTE_INPUT_WAIT then
            local values = {D = entry.city, Z = GetZoneText(), T = PlayerName()}
            SendChat(MTF.FormatAnnouncement(announce.teleportEmoteText, values), "EMOTE")
        end
    end)
end

local function GroupChannel()
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
end

local function OnCast(spellID)
    if MTF.IsSecret(spellID) or type(spellID) ~= "number" then
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    if portals.teleports[name] then
        EmoteTeleport(portals.teleports[name])
        return
    end
    local entry = portals.names[name]
    local announce = MTF.db.announce
    if not entry or not announce.portalGroup then
        return
    end
    local channel = GroupChannel()
    local now = GetTime()
    if not channel or (portals.lastAnnounce and now - portals.lastAnnounce < ANNOUNCE_REPEAT_SECONDS) then
        return
    end
    portals.lastAnnounce = now
    SendChat(MTF.FormatAnnouncement(announce.portalGroupText, {D = entry.city}), channel)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        OnCast(spellID)
    elseif event == "BAG_UPDATE_DELAYED" then
        UpdateCounts()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if portals.resetPending then
            portals.resetPending = false
            PlaceBar()
        end
        if portals.pending then
            MTF.RefreshPortals()
        end
    else
        MTF.RefreshPortals()
    end
end)

function MTF.InitializePortals()
    bar = CreateFrame("Frame", "MageToolsForeverPortals", UIParent, "BackdropTemplate")
    bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}})
    bar:SetBackdropColor(BROWN[1], BROWN[2], BROWN[3], BROWN[4])
    bar:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", StartDrag)
    bar:SetScript("OnDragStop", StopDrag)
    bar.mover = MTF.CreateMover(bar)
    MTF.portalBar = bar
    for index = 1, MAX_BUTTONS do
        portals.buttons[index] = CreateButton(index)
    end
    for _, group in ipairs({TELEPORTS, PORTALS}) do
        local names = group == PORTALS and portals.names or portals.teleports
        for _, entry in ipairs(group) do
            local name = C_Spell.GetSpellName(entry.spell)
            if name then
                names[name] = entry
            end
        end
    end
    PlaceBar()
    for _, event in ipairs({"BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP"}) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    MTF.RefreshPortals()
end

-- /mtf debug_portals: each teleport and portal as the client knows it, and the runes.
function MTF.ReportPortalsDebug()
    for _, group in ipairs({{"teleport", TELEPORTS}, {"portal", PORTALS}}) do
        for _, entry in ipairs(group[2]) do
            -- The client returns no value for an unknown spell; tostring needs one.
            local name = C_Spell.GetSpellName(entry.spell)
            MTF.Report(string.format("debug_portals %s %s spell=%d name=%s known=%s", group[1], entry.city,
                entry.spell, tostring(name), tostring(Known(entry.spell))))
        end
    end
    MTF.Report(string.format("debug_portals runes teleportation=%d portals=%d bar=%s",
        Carried(RUNE_OF_TELEPORTATION), Carried(RUNE_OF_PORTALS), tostring(bar ~= nil and bar:IsShown())))
end
