local _, MTF = ...

-- The AddOn settings: a main page with one switch per module, and a subpage
-- per module for its details, in Blizzard's vertical layout with proxy
-- settings that read and write MageToolsForeverDB directly.
local TITLE = "Mage Tools Forever"
local CONJURE_TITLE = "Conjure"
local SHIELD_TITLE = "Shield"
local CHIMES_TITLE = "Cooldown Chimes"
local PORTALS_TITLE = "Portals"
local POLYMORPH_TITLE = "Polymorph"
local REMINDERS_TITLE = "Buff Reminders"
local ANNOUNCE_TITLE = "Announce"
local UNAVAILABLE = "The AddOn settings page is unavailable on this client. Use /mtf conjure for status."

local REQUIRED_SETTINGS = {
    "RegisterVerticalLayoutCategory", "RegisterVerticalLayoutSubcategory", "RegisterProxySetting",
    "RegisterAddOnCategory", "CreateCheckbox", "CreateSlider", "CreateSliderOptions", "CreateDropdown",
    "CreateControlTextContainer", "OpenToCategory", "NotifyUpdate", "RegisterCanvasLayoutSubcategory",
}

local category
local NestSoundMenu

local function HasSettingsAPI()
    if type(Settings) ~= "table" or type(Settings.VarType) ~= "table" then
        return false
    end
    for _, name in ipairs(REQUIRED_SETTINGS) do
        if type(Settings[name]) ~= "function" then
            return false
        end
    end
    return true
end

local function Proxy(page, variable, variableType, name, default, getValue, setValue)
    return Settings.RegisterProxySetting(page, variable, variableType, name, default, getValue, setValue)
end

-- A checkbox for one saved flag; onChange runs after the value is stored.
local function Flag(page, variable, name, group, key, default, tooltip, onChange)
    local setting = Proxy(page, variable, Settings.VarType.Boolean, name, default,
        function() return MTF.db[group][key] end,
        function(value)
            MTF.db[group][key] = value == true
            if onChange then
                onChange()
            end
        end)
    return Settings.CreateCheckbox(page, setting, tooltip)
end

local function SliderOptions(minValue, maxValue, step)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    return options
end

local function RefreshConjure()
    if MTF.RefreshConjure then
        MTF.RefreshConjure()
    end
end

local function RefreshShield()
    MTF.RefreshShield()
end

local function RefreshPortals()
    MTF.RefreshPortals()
end

local function RefreshPolymorph()
    MTF.RefreshPolymorph()
end

local function RefreshReminders()
    MTF.RefreshReminders()
end

local function AddConjurePage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, CONJURE_TITLE)
    Flag(page, "MTF_CONJURE_MACROS", "Keep conjure macros", "conjure", "macros", true,
        "Keep \"! Water\", \"! Food\", and \"! Mana Gem\" in your character macros for your action bars: "
            .. "left-click eats, drinks, or uses; right-click conjures. Each appears once you know its spell. "
            .. "Turning this off deletes them.",
        function() MTF.ApplyConjureMacros() end)
    local share = Proxy(page, "MTF_CONJURE_SHARE_SIZE", Settings.VarType.Number, "Share stack size",
        MTF.DEFAULT_SHARE_SIZE,
        function() return MTF.db.conjure.shareSize end,
        function(value)
            MTF.db.conjure.shareSize = MTF.SanitizeShareSize(value)
        end)
    local scale = Proxy(page, "MTF_CONJURE_SCALE", Settings.VarType.Number, "Bar size (%)", MTF.DEFAULT_SCALE,
        function() return MTF.db.conjure.scale end,
        function(value)
            MTF.db.conjure.scale = MTF.SanitizeScale(value)
            RefreshConjure()
        end)
    Settings.CreateSlider(page, scale, SliderOptions(MTF.SCALE_MIN, MTF.SCALE_MAX, MTF.SCALE_STEP),
        "How big the conjure bar is, in percent. A change in combat applies when combat ends.")
    Settings.CreateSlider(page, share, SliderOptions(MTF.SHARE_SIZE_MIN, MTF.SHARE_SIZE_MAX, 1),
        "How much food or water one left-click trade gives your target. If you carry less, they get all of it.")
end

local function AddPortalsPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, PORTALS_TITLE)
    local scale = Proxy(page, "MTF_PORTALS_SCALE", Settings.VarType.Number, "Bar size (%)", MTF.DEFAULT_SCALE,
        function() return MTF.db.portals.scale end,
        function(value)
            MTF.db.portals.scale = MTF.SanitizeScale(value)
            RefreshPortals()
        end)
    Settings.CreateSlider(page, scale, SliderOptions(MTF.SCALE_MIN, MTF.SCALE_MAX, MTF.SCALE_STEP),
        "How big the portal bar is, in percent. A change in combat applies when combat ends.")
end

local function AddPolymorphPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, POLYMORPH_TITLE)
    Flag(page, "MTF_POLYMORPH_MACRO", "Keep the Polymorph macro", "polymorph", "macro", true,
        "Keep \"! Polymorph\" in your character macros for your action bars, once you know Polymorph: it focuses "
            .. "the hostile mob under your mouse (or your target, out of combat) and sheeps your focus, which the "
            .. "bar's click recasts on. Turning this off deletes it.", function() MTF.ApplyPolymorphMacro() end)
    Flag(page, "MTF_POLYMORPH_MARK", "Mark the sheep with the moon", "polymorph", "mark", true,
        "When your Polymorph cast succeeds, put the moon raid marker on the mob. In a raid the game "
            .. "lets only the leader and assistants mark.")
    local scale = Proxy(page, "MTF_POLYMORPH_SCALE", Settings.VarType.Number, "Bar size (%)", MTF.DEFAULT_SCALE,
        function() return MTF.db.polymorph.scale end,
        function(value)
            MTF.db.polymorph.scale = MTF.SanitizeScale(value)
            RefreshPolymorph()
        end)
    Settings.CreateSlider(page, scale, SliderOptions(MTF.SCALE_MIN, MTF.SCALE_MAX, MTF.SCALE_STEP),
        "How big the Polymorph bar is, in percent. A change in combat applies when combat ends.")
end

local function AddRemindersPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, REMINDERS_TITLE)
    for _, reminder in ipairs(MTF.REMINDERS) do
        local setting = Proxy(page, "MTF_REMINDER_" .. reminder.key:upper(), Settings.VarType.Boolean,
            reminder.label, reminder.on,
            function() return MTF.db.reminders.spells[reminder.key] end,
            function(value)
                MTF.db.reminders.spells[reminder.key] = value == true
                RefreshReminders()
            end)
        Settings.CreateCheckbox(page, setting, "Show an icon with a pulsing border while you lack "
            .. reminder.label .. ", out of combat.")
    end
    Flag(page, "MTF_REMINDER_GROUP", "Arcane Intellect: also your group", "reminders", "group", true,
        "Also remind you when a party or raid member who uses mana lacks Arcane Intellect or Arcane Brilliance. "
            .. "The icon shows how many, and its tooltip who.", RefreshReminders)
end

local function AddShieldPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, SHIELD_TITLE)
    Flag(page, "MTF_SHIELD_NUMBER", "Show the absorb amount", "shield", "number", true,
        "Show your remaining absorb as a number beside the ring.", RefreshShield)
    local soundSwitch = Flag(page, "MTF_SHIELD_BREAK_SOUND", "Sound when a shield ends", "shield", "breakSound",
        false,
        "Play a sound when your Ice Barrier, Mana Shield, Fire Ward, or Frost Ward ends or breaks, also in combat.",
        RefreshShield)
    local display = MTF.ShieldDisplay
    -- Which sound, under its switch (author-approved: a default you can change).
    local sound = Proxy(page, "MTF_SHIELD_BREAK_SOUND_CHOICE", Settings.VarType.String, "Sound",
        display.DEFAULT_BREAK_SOUND,
        function() return MTF.db.shield.breakSoundKey end,
        function(value)
            MTF.db.shield.breakSoundKey = display.SanitizeBreakSound(value)
            RefreshShield()
            display.PreviewBreakSound()
        end)
    local function SoundChoices()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(display.BREAK_SOUNDS) do
            container:Add(choice.key, choice.label)
        end
        return container:GetData()
    end
    local dropdown = Settings.CreateDropdown(page, sound, SoundChoices,
        "The sound when a shield ends. Choosing one plays it once.")
    dropdown:SetParentInitializer(soundSwitch, function() return MTF.db.shield.breakSound end)
    local scale = Proxy(page, "MTF_SHIELD_SCALE", Settings.VarType.Number, "Display size (%)", display.DEFAULT_SCALE,
        function() return MTF.db.shield.scale end,
        function(value)
            MTF.db.shield.scale = display.SanitizeScale(value)
            RefreshShield()
        end)
    Settings.CreateSlider(page, scale, SliderOptions(display.SCALE_MIN, display.SCALE_MAX, display.SCALE_STEP),
        "How big the shield display is, in percent.")
end

-- The sound menu: a submenu per group and a top-level entry for a sound with
-- no group, as the Cooldown Manager's sound picker (CooldownViewerUtil
-- .BuildSoundMenus) builds it with the same menu API. Blizzard's settings
-- dropdown builds its menu in its control's SetupDropdownMenu; the control
-- frames are pooled and shared with other settings, so the replacement
-- builds the nested menu only for an MTF sound dropdown and hands every
-- other one back to Blizzard's.
local function SoundMenuInserter(setting, rootDescription)
    local function IsSelected(key)
        return setting:GetValue() == key
    end
    local function SetSelected(key)
        setting:SetValue(key)
    end
    for _, group in ipairs(MTF.ChimeSoundGroups()) do
        if #group.sounds == 1 and not MTF.ChimeSoundParts(group.sounds[1]) then
            rootDescription:CreateRadio(group.sounds[1].label, IsSelected, SetSelected, group.sounds[1].key)
        else
            local submenu = rootDescription:CreateButton(group.name)
            for _, choice in ipairs(group.sounds) do
                local _, name = MTF.ChimeSoundParts(choice)
                submenu:CreateRadio(name, IsSelected, SetSelected, choice.key)
            end
        end
    end
end

local function NestedSetupDropdownMenu(original)
    return function(control, button, setting, options, initTooltip, initializer)
        if not (initializer and initializer.mtfSoundMenu) then
            return original(control, button, setting, options, initTooltip, initializer)
        end
        Settings.InitDropdown(button, setting, SoundMenuInserter, initTooltip)
    end
end

function NestSoundMenu(initializer)
    if type(initializer.InitFrame) ~= "function" or type(Settings.InitDropdown) ~= "function" then
        return
    end
    initializer.mtfSoundMenu = true
    initializer.data = initializer.data or {}
    -- A menu of submenus has no single list to step through.
    initializer.data.forceSteppersHidden = true
    -- The dropdown shows the full label, "Short: Bell Strike".
    initializer.getSelectionTextFunc = function()
        return MTF.ChimeSoundLabel(initializer:GetSetting():GetValue()) or ""
    end
    local initFrame = initializer.InitFrame
    function initializer:InitFrame(frame)
        if type(frame.SetupDropdownMenu) == "function" and not frame.mtfNestedSoundMenu then
            frame.mtfNestedSoundMenu = true
            frame.SetupDropdownMenu = NestedSetupDropdownMenu(frame.SetupDropdownMenu)
        end
        return initFrame(self, frame)
    end
end

local function AddChimesPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, CHIMES_TITLE)
    -- Every sound by its full label: the dropdown's plain list, used when the
    -- nested menu below is not set up.
    local function Choices()
        local container = Settings.CreateControlTextContainer()
        for _, sound in ipairs(MTF.AvailableChimeSounds()) do
            container:Add(sound.key, sound.label)
        end
        return container:GetData()
    end
    local lead = Proxy(page, "MTF_CHIMES_LEAD", Settings.VarType.Number, "Chime early (seconds)",
        MTF.DEFAULT_CHIME_LEAD,
        function() return MTF.db.chimes.lead end,
        function(value)
            MTF.db.chimes.lead = MTF.SanitizeChimeLead(value)
        end)
    Settings.CreateSlider(page, lead, SliderOptions(MTF.CHIME_LEAD_MIN, MTF.CHIME_LEAD_MAX, MTF.CHIME_LEAD_STEP),
        "How long before a cooldown ends the chime plays, so you can act the moment it is ready.")
    for _, chime in ipairs(MTF.CHIME_SPELLS) do
        local setting = Proxy(page, "MTF_CHIME_" .. chime.key:upper(), Settings.VarType.Boolean, chime.label,
            chime.on,
            function() return MTF.db.chimes.spells[chime.key] end,
            function(value) MTF.db.chimes.spells[chime.key] = value == true end)
        local switch = Settings.CreateCheckbox(page, setting, "Chime when " .. chime.label .. " is ready again.")
        -- Each spell's own sound (author-approved), under its switch, in a menu
        -- of submenus as the Cooldown Manager's sound picker has.
        local sound = Proxy(page, "MTF_CHIME_SOUND_" .. chime.key:upper(), Settings.VarType.String, "Sound",
            MTF.DEFAULT_CHIME_SOUND,
            function() return MTF.db.chimes.sounds[chime.key] end,
            function(value)
                for _, choice in ipairs(MTF.CHIME_SOUNDS) do
                    if choice.key == value then
                        MTF.db.chimes.sounds[chime.key] = value
                        MTF.PreviewChime(chime.key)
                    end
                end
            end)
        local dropdown = Settings.CreateDropdown(page, sound, Choices,
            "The sound for " .. chime.label .. ". Choosing one plays it once.")
        NestSoundMenu(dropdown)
        dropdown:SetParentInitializer(switch, function() return MTF.db.chimes.spells[chime.key] end)
    end
end

-- Announce page --------------------------------------------------------------
-- A canvas page as WTF's: each message's switch over a wrapping box with its
-- text, which scrolls when taller than the Settings panel.

local ANNOUNCE_ROWS = {
    {switch = "waterWhisper", label = "Water trade: whisper the player"},
    {switch = "foodWhisper", label = "Food trade: whisper the player"},
    {switch = "bothWhisper", label = "Food & Water trade: whisper the player"},
    {switch = "portalGroup", label = "Portal: tell the group (raid or party; nothing when alone)"},
    {switch = "polymorphGroup", label = "Polymorph: tell the group as you start casting (raid or party)"},
    {switch = "teleportEmote", label = "Teleport: emote (starts with your name; sent at your next key press or click)"},
}
local PAGE_LEFT = 16
local ROW_GAP = 10
local EDIT_INDENT = 8
local EDIT_WIDTH = 560
local PAGE_BOTTOM = 16
local SCROLL_BAR_SPACE = 28
local EDIT_LINES = 3
local EDIT_LINE_HEIGHT = 14
local EDIT_PADDING = 6
local EDIT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = {left = 3, right = 3, top = 3, bottom = 3},
}

local function Text(parent, font, text)
    local label = parent:CreateFontString(nil, "ARTWORK", font)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function CreateAnnouncePage()
    local page = CreateFrame("Frame")
    page.rows = {}
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_SPACE, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(EDIT_WIDTH + 2 * PAGE_LEFT, 1)
    scroll:SetScrollChild(content)
    page.scroll, page.content = scroll, content
    local title = Text(content, "GameFontHighlightHuge", ANNOUNCE_TITLE)
    title:SetPoint("TOPLEFT", PAGE_LEFT, -16)
    local help = Text(content, "GameFontHighlightSmall",
        "%C is the count, %I the item (for Food & Water, both of them), %T the player's full name (for Polymorph, the mob), and %D "
            .. "the portal's or teleport's city (in the emote, %T is you and %Z your zone when it is sent). Press Enter to keep an edit, Escape to undo it. A player is whispered at "
            .. "most once every 30 seconds.")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    help:SetWidth(EDIT_WIDTH)

    local previous = help
    for index, row in ipairs(ANNOUNCE_ROWS) do
        local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        check.label = Text(check, "GameFontHighlight", row.label)
        check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        if index == 1 then
            check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -16)
        else
            check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", -EDIT_INDENT, -ROW_GAP)
        end
        check:SetScript("OnClick", function(self)
            MTF.db.announce[row.switch] = self:GetChecked() == true
        end)
        -- Messages are one chat line, so Enter keeps the edit.
        local box = CreateFrame("Frame", nil, content, "BackdropTemplate")
        box:SetSize(EDIT_WIDTH, EDIT_LINES * EDIT_LINE_HEIGHT + 2 * EDIT_PADDING)
        box:SetPoint("TOPLEFT", check, "BOTTOMLEFT", EDIT_INDENT, -2)
        box:SetBackdrop(EDIT_BACKDROP)
        box:SetBackdropColor(0, 0, 0, 0.6)
        box:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        local edit = CreateFrame("EditBox", nil, box)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(EDIT_WIDTH - 2 * EDIT_PADDING)
        edit:SetPoint("TOPLEFT", EDIT_PADDING, -EDIT_PADDING)
        edit:SetAutoFocus(false)
        edit:SetMaxBytes(MTF.ANNOUNCE_MAX_LENGTH + 1)
        box:EnableMouse(true)
        box:SetScript("OnMouseDown", function() edit:SetFocus() end)
        local key = row.switch .. "Text"
        local function Commit(self)
            local text = self:GetText():gsub("[\r\n]+", " ")
            MTF.db.announce[key] = MTF.SanitizeAnnouncement(text, MTF.ANNOUNCE_DEFAULTS[key])
            self:SetText(MTF.db.announce[key])
        end
        edit:SetScript("OnEnterPressed", function(self)
            Commit(self)
            self:ClearFocus()
        end)
        edit:SetScript("OnEditFocusLost", Commit)
        edit:SetScript("OnEscapePressed", function(self)
            self:SetText(MTF.db.announce[key])
            self:ClearFocus()
        end)
        page.rows[#page.rows + 1] = {check = check, edit = edit, switch = row.switch, key = key}
        previous = box
    end
    local last = previous

    local function FitContent()
        local top, bottom = content:GetTop(), last:GetBottom()
        if type(top) == "number" and type(bottom) == "number" then
            content:SetHeight(top - bottom + PAGE_BOTTOM)
        end
    end

    function page:OnRefresh()
        FitContent()
        local settings = MTF.db.announce
        for _, row in ipairs(self.rows) do
            row.check:SetChecked(settings[row.switch])
            row.edit:SetText(settings[row.key])
            row.edit:SetCursorPosition(0)
        end
    end

    -- The Settings panel's Defaults button restores this page only.
    function page:OnDefault()
        local settings = MTF.db.announce
        for _, row in ipairs(self.rows) do
            settings[row.switch] = true
            settings[row.key] = MTF.ANNOUNCE_DEFAULTS[row.key]
        end
        self:OnRefresh()
    end

    page:SetScript("OnShow", page.OnRefresh)
    return page
end

function MTF.InitializeOptions()
    if not HasSettingsAPI() then
        return
    end
    category = Settings.RegisterVerticalLayoutCategory(TITLE)
    Flag(category, "MTF_CONJURE_ENABLED", "Conjure bar", "conjure", "enabled", true,
        "A bar with water, food, and mana gem buttons: left-click uses or trades, right-click conjures.",
        RefreshConjure)
    Flag(category, "MTF_PORTALS_ENABLED", "Portal bar", "portals", "enabled", true,
        "A bar with a button for each teleport and portal you know, and the runes you carry for them.",
        RefreshPortals)
    Flag(category, "MTF_POLYMORPH_ENABLED", "Polymorph bar", "polymorph", "enabled", true,
        "A bar with your Polymorph's time left and the sheeped mob's name; click it to sheep the mob again.",
        RefreshPolymorph)
    Flag(category, "MTF_REMINDERS_ENABLED", "Buff reminders", "reminders", "enabled", true,
        "An icon with a pulsing border for each buff you lack, out of combat: Arcane Intellect and your armor.",
        RefreshReminders)
    Flag(category, "MTF_SHIELD_ENABLED", "Shield display", "shield", "enabled", true,
        "A crescent beside your character that fills with your remaining shield, full when it lands.",
        RefreshShield)
    Flag(category, "MTF_CHIMES_ENABLED", "Cooldown chimes", "chimes", "enabled", true,
        "A sound just before Blink, Frost Nova, and your other chosen spells are ready again.")
    local unlocked = Proxy(category, "MTF_UNLOCKED", Settings.VarType.Boolean, "Unlock frames to move them", false,
        function() return not MTF.db.locked end,
        function(value) MTF.SetFramesLocked(value ~= true) end)
    Settings.CreateCheckbox(category, unlocked,
        "Outline every MTF frame (the conjure, portal, and Polymorph bars, the buff reminders, and the "
            .. "shield display) so you can drag them, and scroll a buff reminder to resize it; untick to lock them again. "
            .. "/mtf unlock and /mtf lock do the same, and /mtf reset moves them back to their default places.")
    local grid = Proxy(category, "MTF_GRID", Settings.VarType.Boolean, "Show a grid while unlocked", true,
        function() return MTF.db.grid end,
        function(value)
            MTF.db.grid = value == true
            MTF.RefreshGrid()
        end)
    Settings.CreateCheckbox(category, grid, "While frames are unlocked, draw a faint grid over the screen with "
        .. "the center lines in red, so you can line frames up.")
    AddConjurePage(category)
    AddShieldPage(category)
    AddPortalsPage(category)
    AddPolymorphPage(category)
    AddRemindersPage(category)
    AddChimesPage(category)
    local announcePage = CreateAnnouncePage()
    MTF.announcePage = announcePage
    Settings.RegisterCanvasLayoutSubcategory(category, announcePage, ANNOUNCE_TITLE)
    Settings.RegisterAddOnCategory(category)
end

function MTF.OpenSettings()
    if not category then
        MTF.Report(UNAVAILABLE)
        return
    end
    Settings.OpenToCategory(category:GetID())
end
