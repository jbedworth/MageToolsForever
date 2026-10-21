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

-- A widget's size sliders (Dyre's Toolkit: each with a gold mark at its
-- default, then "Reset size"), with the label players know.
local function AddWidgetSizes(page, layout, widget, tooltips, resetTooltip)
    if widget then
        MTF.toolkit.AddWidgetSettings(page, layout, widget,
            {labels = {scale = "Bar size (%)", width = "Bar width"}, tooltips = tooltips, resetTooltip = resetTooltip})
    end
end

local function AddConjurePage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, CONJURE_TITLE)
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
    Settings.CreateSlider(page, share, SliderOptions(MTF.SHARE_SIZE_MIN, MTF.SHARE_SIZE_MAX, 1),
        "How much food or water one left-click trade gives your target. If you carry less, they get all of it.")
    AddWidgetSizes(page, layout, MTF.conjureWidget,
        {scale = "How big the conjure bar is, in percent. A change in combat applies when combat ends."})
end

local function AddPortalsPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, PORTALS_TITLE)
    AddWidgetSizes(page, layout, MTF.portalWidget,
        {scale = "How big the portal bar is, in percent. A change in combat applies when combat ends."})
end

local function AddPolymorphPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, POLYMORPH_TITLE)
    Flag(page, "MTF_POLYMORPH_MACRO", "Keep the Polymorph macro", "polymorph", "macro", true,
        "Keep \"! Polymorph\" in your character macros for your action bars, once you know Polymorph: it focuses "
            .. "the hostile mob under your mouse (or your target, out of combat) and sheeps your focus, which the "
            .. "bar's click recasts on. Turning this off deletes it.", function() MTF.ApplyPolymorphMacro() end)
    Flag(page, "MTF_POLYMORPH_MARK", "Mark the sheep with the moon", "polymorph", "mark", true,
        "\"! Polymorph\" and a click on the bar put the moon raid marker on the mob as you press them, also in "
            .. "combat. A Polymorph from the plain spell button gets no moon: the game does not let AddOns set "
            .. "markers. In a raid the game lets only the leader and assistants mark.",
        function() MTF.RefreshPolymorph() end)
    AddWidgetSizes(page, layout, MTF.polymorphWidget, {
        scale = "How big the Polymorph bar is, in percent, on top of its width, height, and text size. A change "
            .. "in combat applies when combat ends.",
        width = "The Polymorph bar's width. A change in combat applies when combat ends.",
        barHeight = "The height of the bar line; the icon follows. A change in combat applies when combat ends.",
        textScale = "The size of the mob's name and the bar's texts. A change in combat applies when combat ends.",
        opacity = "How solid the whole Polymorph bar is. It fades at once, also in combat; its timer bar follows "
            .. "when combat ends.",
    }, "Back to the bar's own width, height, and text size. Bar size (%) and Opacity stay as they are.")
end

local REMINDERS_ELSEWHERE = " Dyre's Buff Reminders shows your buff reminders now, so these icons stay hidden. Type /dbr to change them."

-- Greys out a setting another Dyre's AddOn now handles (Dyre's Buff Reminders,
-- Dyre's Cooldown Chimes): it shows its saved value but cannot be changed here.
local function Grey(initializer, aside)
    if aside and type(initializer) == "table" and type(initializer.AddModifyPredicate) == "function" then
        initializer:AddModifyPredicate(function() return false end)
    end
    return initializer
end

-- A page whose feature a stand-alone Dyre's AddOn now runs (author-approved rule)
-- says so twice: its name in the settings list names that AddOn, and a heading
-- with a tooltip tops the page. Headings as Blizzard's Controls page adds them
-- (Blizzard_SettingControls.lua: CreateSettingsListSectionHeaderInitializer).
local function ManagedTitle(title, addonTitle, managed)
    return managed and (title .. " (" .. addonTitle .. ")") or title
end

local function ManagedHeading(layout, managed, heading, tooltip)
    if managed and type(CreateSettingsListSectionHeaderInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(heading, tooltip))
    end
end

local function AddRemindersPage(parent)
    local aside = MTF.RemindersStandAside()
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent,
        ManagedTitle(REMINDERS_TITLE, "Dyre's Buff Reminders", aside))
    ManagedHeading(layout, aside, "Buff reminders are now managed by Dyre's Buff Reminders",
        "Use /dbr to change them. "
            .. "MTF keeps its own settings as they are, and uses them again if you remove Dyre's Buff Reminders.")
    local note = aside and REMINDERS_ELSEWHERE or ""
    for _, reminder in ipairs(MTF.REMINDERS) do
        local setting = Proxy(page, "MTF_REMINDER_" .. reminder.key:upper(), Settings.VarType.Boolean,
            reminder.label, reminder.on,
            function() return MTF.db.reminders.spells[reminder.key] end,
            function(value)
                MTF.db.reminders.spells[reminder.key] = value == true
                RefreshReminders()
            end)
        Grey(Settings.CreateCheckbox(page, setting, "Show an icon with a pulsing border while you lack "
            .. reminder.label .. ", out of combat." .. note), aside)
    end
    Grey(Flag(page, "MTF_REMINDER_GROUP", "Arcane Intellect: also your group", "reminders", "group", true,
        "Also remind you when a party or raid member who uses mana lacks Arcane Intellect or Arcane Brilliance. "
            .. "The icon shows how many, and its tooltip who." .. note, RefreshReminders), aside)
end

-- The shield display draws in one AddOn only (Shield.lua's election); in the
-- others its settings do nothing, so they are greyed out (author-approved) with
-- a note naming the AddOn that draws it. Checked each time the page shows.
local SHIELD_ELSEWHERE = " Dyre's Shields Up shows the shield display now, so these settings do nothing "
    .. "here. Type /dsu to change it. MTF keeps its own shield settings as they are."

local function ShieldOwnerNote(display)
    if MTF.ShieldStandAside() then
        return SHIELD_ELSEWHERE
    end
    if display.IsOwner() then
        return ""
    end
    local owner = display.OwnerAddOn()
    local title = owner and type(C_AddOns) == "table" and type(C_AddOns.GetAddOnMetadata) == "function"
        and C_AddOns.GetAddOnMetadata(owner, "Title")
    if type(title) ~= "string" or title == "" then
        title = tostring(owner)
    end
    return " " .. title .. " draws the shield display, so use its settings for it."
end

local function GreyUnlessOwner(initializer, display)
    if type(initializer) == "table" and type(initializer.AddModifyPredicate) == "function" then
        initializer:AddModifyPredicate(function() return not MTF.ShieldStandAside() and display.IsOwner() end)
    end
    return initializer
end

local function AddShieldPage(parent)
    local aside = MTF.ShieldStandAside()
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent,
        ManagedTitle(SHIELD_TITLE, "Dyre's Shields Up", aside))
    ManagedHeading(layout, aside, "Shields are now managed by Dyre's Shields Up",
        "Use /dsu to change the shield display. "
            .. "MTF keeps its own settings as they are, and uses them again if you remove Dyre's Shields Up.")
    local display = MTF.ShieldDisplay
    local note = ShieldOwnerNote(display)
    GreyUnlessOwner(Flag(page, "MTF_SHIELD_NUMBER", "Show the absorb amount", "shield", "number", true,
        "Show your remaining absorb as a number beside the ring." .. note, RefreshShield), display)
    local soundSwitch = GreyUnlessOwner(Flag(page, "MTF_SHIELD_BREAK_SOUND", "Sound when a shield ends",
        "shield", "breakSound", false,
        "Play a sound when your Ice Barrier, Mana Shield, Fire Ward, or Frost Ward ends or breaks, "
            .. "also in combat." .. note,
        RefreshShield), display)
    -- Which sound, under its switch (author-approved: a default you can change).
    local sound = Proxy(page, "MTF_SHIELD_BREAK_SOUND_CHOICE", Settings.VarType.String, "Sound",
        display.DEFAULT_BREAK_SOUND,
        function() return MTF.db.shield.breakSoundKey end,
        function(value)
            MTF.db.shield.breakSoundKey = display.SanitizeBreakSound(value)
            RefreshShield()
            display.PreviewBreakSound()
        end)
    -- The sounds come from Dyre's Sounds; without it the list is empty.
    local dropdown = Settings.CreateDropdown(page, sound, display.SoundChoices,
        "The sound when a shield ends. Choosing one plays it once. The sounds come from Dyre's Sounds." .. note)
    display.SetupSoundMenu(dropdown)
    GreyUnlessOwner(dropdown, display)
    if type(dropdown.SetParentInitializer) == "function" then
        dropdown:SetParentInitializer(soundSwitch, function() return MTF.db.shield.breakSound end)
    end
    local scale = Proxy(page, "MTF_SHIELD_SCALE", Settings.VarType.Number, "Display size (%)", display.DEFAULT_SCALE,
        function() return MTF.db.shield.scale end,
        function(value)
            MTF.db.shield.scale = display.SanitizeScale(value)
            RefreshShield()
        end)
    GreyUnlessOwner(Settings.CreateSlider(page, scale,
        SliderOptions(display.SCALE_MIN, display.SCALE_MAX, display.SCALE_STEP),
        "How big the shield display is, in percent." .. note), display)
end

local NO_SOUNDS = " Install Dyre's Sounds to hear them and to choose each spell's sound."

-- What the chime settings add to their tooltips: which Dyre's AddOn plays the
-- chimes, or that the sounds need Dyre's Sounds.
local function ChimesNote(library)
    local owner = MTF.ChimesOwner()
    if owner then
        return " " .. owner.title .. " is installed and plays the chimes instead, so MTF plays none: "
            .. "use its settings (" .. owner.slash .. "). MTF keeps these settings as they are."
    end
    if not library then
        return NO_SOUNDS
    end
    return ""
end

local function AddChimesPage(parent)
    local owner = MTF.ChimesOwner()
    local aside = owner ~= nil
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent,
        ManagedTitle(CHIMES_TITLE, owner and owner.title, aside))
    ManagedHeading(layout, aside, owner and ("Cooldown chimes are now managed by " .. owner.title),
        owner and ("Use " .. owner.slash .. " to change them. "
            .. "MTF keeps its own settings as they are, and uses them again if you remove " .. owner.title .. "."))
    local library = MTF.SoundLibrary()
    local note = ChimesNote(library)
    local lead = Proxy(page, "MTF_CHIMES_LEAD", Settings.VarType.Number, "Chime early (seconds)",
        MTF.DEFAULT_CHIME_LEAD,
        function() return MTF.db.chimes.lead end,
        function(value)
            MTF.db.chimes.lead = MTF.SanitizeChimeLead(value)
        end)
    Grey(Settings.CreateSlider(page, lead, SliderOptions(MTF.CHIME_LEAD_MIN, MTF.CHIME_LEAD_MAX, MTF.CHIME_LEAD_STEP),
        "How long before a cooldown ends the chime plays, so you can act the moment it is ready." .. note), aside)
    for _, chime in ipairs(MTF.CHIME_SPELLS) do
        local setting = Proxy(page, "MTF_CHIME_" .. chime.key:upper(), Settings.VarType.Boolean, chime.label,
            chime.on,
            function() return MTF.db.chimes.spells[chime.key] end,
            function(value) MTF.db.chimes.spells[chime.key] = value == true end)
        local switch = Grey(Settings.CreateCheckbox(page, setting,
            "Chime when " .. chime.label .. " is ready again." .. note), aside)
        -- Each spell's own sound (author-approved), under its switch, in Dyre's
        -- Sounds' menu of submenus, as the Cooldown Manager's sound picker has.
        -- Without the library there is no list to choose from.
        if library then
            local sound = Proxy(page, "MTF_CHIME_SOUND_" .. chime.key:upper(), Settings.VarType.String, "Sound",
                MTF.DEFAULT_CHIME_SOUND,
                function() return MTF.db.chimes.sounds[chime.key] end,
                function(value)
                    local key = library.Resolve(value)
                    if key then
                        MTF.db.chimes.sounds[chime.key] = key
                        MTF.PreviewChime(chime.key)
                    end
                end)
            local dropdown = Settings.CreateDropdown(page, sound, library.Choices(),
                "The sound for " .. chime.label .. ". Choosing one plays it once. Text to Speech says \""
                    .. chime.label .. " ready\"." .. note)
            library.SetupMenu(dropdown)
            Grey(dropdown, aside)
            if type(dropdown.SetParentInitializer) == "function" then
                dropdown:SetParentInitializer(switch, function() return MTF.db.chimes.spells[chime.key] end)
            end
        end
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
    -- With Dyre's Toolkit, MTF's page sits under its "Dyre's AddOns" home,
    -- and MTF's pages under that (the settings list draws any depth).
    if MTF.toolkit then
        category = MTF.toolkit.RegisterSettingsCategory(TITLE)
    end
    local ownCategory = category == nil
    if ownCategory then
        category = Settings.RegisterVerticalLayoutCategory(TITLE)
    end
    Flag(category, "MTF_CONJURE_ENABLED", "Conjure bar", "conjure", "enabled", true,
        "A bar with water, food, and mana gem buttons: left-click uses or trades, right-click conjures.",
        RefreshConjure)
    Flag(category, "MTF_PORTALS_ENABLED", "Portal bar", "portals", "enabled", true,
        "A bar with a button for each teleport and portal you know, and the runes you carry for them.",
        RefreshPortals)
    Flag(category, "MTF_POLYMORPH_ENABLED", "Polymorph bar", "polymorph", "enabled", true,
        "A bar with your Polymorph's time left and the sheeped mob's name; click it to sheep the mob again.",
        RefreshPolymorph)
    local remindersAside = MTF.RemindersStandAside()
    Grey(Flag(category, "MTF_REMINDERS_ENABLED", "Buff reminders", "reminders", "enabled", true,
        "An icon with a pulsing border for each buff you lack, out of combat: Arcane Intellect and your armor."
            .. (remindersAside and REMINDERS_ELSEWHERE or ""), RefreshReminders), remindersAside)
    GreyUnlessOwner(Flag(category, "MTF_SHIELD_ENABLED", "Shield display", "shield", "enabled", true,
        "A crescent beside your character that fills with your remaining shield, full when it lands."
            .. ShieldOwnerNote(MTF.ShieldDisplay), RefreshShield), MTF.ShieldDisplay)
    Grey(Flag(category, "MTF_CHIMES_ENABLED", "Cooldown chimes", "chimes", "enabled", true,
        "A sound just before Blink, Frost Nova, and your other chosen spells are ready again."
            .. ChimesNote(MTF.SoundLibrary())), MTF.ChimesStandAside())
    AddConjurePage(category)
    AddShieldPage(category)
    AddPortalsPage(category)
    AddPolymorphPage(category)
    AddRemindersPage(category)
    AddChimesPage(category)
    local announcePage = CreateAnnouncePage()
    MTF.announcePage = announcePage
    Settings.RegisterCanvasLayoutSubcategory(category, announcePage, ANNOUNCE_TITLE)
    if ownCategory then
        Settings.RegisterAddOnCategory(category)
    end
end

function MTF.OpenSettings()
    if not category then
        MTF.Report(UNAVAILABLE)
        return
    end
    if MTF.toolkit then
        -- The toolkit opens it, never in combat.
        MTF.toolkit.OpenSettings(category)
        return
    end
    Settings.OpenToCategory(category:GetID())
end
