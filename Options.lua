local _, MTF = ...

-- The AddOn settings: a main page with one switch per module, and a subpage
-- per module for its details, in Blizzard's vertical layout with proxy
-- settings that read and write MageToolsForeverDB directly. The Shield,
-- Reminders, Chimes, Procs, and Polymorph pages show the settings of
-- Dyre's Shields Up, Dyre's Buff Reminders, and Dyre's Debuff Tracker through
-- Dyre's Toolkit, or a link to them (see AddCompanionPage).
local TITLE = "Mage Tools Forever"
local CONJURE_TITLE = "Conjure"
local PORTALS_TITLE = "Portals"
local ANNOUNCE_TITLE = "Announce"
-- The companion sections' names while their owners are missing (see SectionTitle).
local SHIELD_TITLE = "Shield display"
local REMINDERS_TITLE = "Reminders"
local CHIMES_TITLE = "Chimes"
local PROCS_TITLE = "Procs"
local CUES_TITLE = "Debuff Cues"
local POLYMORPH_TITLE = "Crowd Control"
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

local function RefreshPortals()
    MTF.RefreshPortals()
end

-- A row is greyed while the switch for its feature is off (John, 2026-11-27:
-- "when the top-level is off, the settings that are controlling a disabled
-- feature should be disabled too"). The settings list runs the predicate each
-- time it draws the row.
local function ConjureOn()
    return MTF.db.conjure.enabled == true
end

local function PortalsOn()
    return MTF.db.portals.enabled == true
end

local function WhileOn(initializer, predicate)
    if type(initializer) == "table" and type(initializer.AddModifyPredicate) == "function" then
        initializer:AddModifyPredicate(predicate)
    end
    return initializer
end

-- A widget's size sliders (Dyre's Toolkit: each with a gold mark at its
-- default, then "Reset size"), with the label players know, greyed while
-- modify gives false (opts.modify, Toolkit 2.17.0; an older one ignores it).
local function AddWidgetSizes(page, layout, widget, tooltips, modify)
    if widget then
        MTF.toolkit.AddWidgetSettings(page, layout, widget,
            {labels = {scale = "Bar size", width = "Bar width"}, tooltips = tooltips, modify = modify})
    end
end

-- "Layout": Horizontal or Vertical (Dyre's Toolkit 2.18.0; none with an
-- older one), greyed while the bar is off.
local function AddBarLayout(page, layout, widget, tooltip, modify)
    if widget and MTF.HasBarLayout() and type(MTF.toolkit.AddBarLayoutSetting) == "function" then
        MTF.toolkit.AddBarLayoutSetting(page, layout, widget, {tooltip = tooltip, modify = modify})
    end
end

-- "Keep conjure macros" stays usable with the bar off: the macros work
-- without it. The share size, Shift-click, and the bar's size are the bar's.
local function AddConjurePage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, CONJURE_TITLE)
    Flag(page, "MTF_CONJURE_MACROS", "Keep conjure macros", "conjure", "macros", true,
        "Keeps \"! Water\", \"! Food\", and \"! Mana Gem\" macros for your action bars: left-click eats, "
            .. "drinks, or uses, and right-click conjures. Turning this off deletes them.",
        function() MTF.ApplyConjureMacros() end)
    local share = Proxy(page, "MTF_CONJURE_SHARE_SIZE", Settings.VarType.Number, "Share stack size",
        MTF.DEFAULT_SHARE_SIZE,
        function() return MTF.db.conjure.shareSize end,
        function(value)
            MTF.db.conjure.shareSize = MTF.SanitizeShareSize(value)
        end)
    local shareSlider = Settings.CreateSlider(page, share, SliderOptions(MTF.SHARE_SIZE_MIN, MTF.SHARE_SIZE_MAX, 1),
        "How much food or water one trade gives your target.")
    WhileOn(shareSlider, ConjureOn)
    -- The gold mark at the default, as on the Toolkit's own sliders (John:
    -- "set notches on the sliders default values"; public since Toolkit 2.2.0).
    if MTF.toolkit and type(MTF.toolkit.AddDefaultTick) == "function" then
        MTF.toolkit.AddDefaultTick(shareSlider,
            {min = MTF.SHARE_SIZE_MIN, max = MTF.SHARE_SIZE_MAX, default = MTF.DEFAULT_SHARE_SIZE})
    end
    WhileOn(Flag(page, "MTF_CONJURE_SHIFT_TRADE", "Trade only with Shift-click", "conjure", "shiftTrade", false,
        "Left-click on Water, Food, and Food & Water always eats or drinks, and Shift + left-click trades "
            .. "to your target.",
        RefreshConjure), ConjureOn)
    AddBarLayout(page, layout, MTF.conjureWidget,
        "Whether the conjure bar's buttons go side by side or top to bottom.", ConjureOn)
    AddWidgetSizes(page, layout, MTF.conjureWidget,
        {scale = "How big the conjure bar is, in percent."},
        ConjureOn)
end

local function AddPortalsPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, PORTALS_TITLE)
    AddBarLayout(page, layout, MTF.portalWidget,
        "Whether the portal bar's buttons go side by side or top to bottom.", PortalsOn)
    AddWidgetSizes(page, layout, MTF.portalWidget,
        {scale = "How big the portal bar is, in percent."},
        PortalsOn)
end

-- A page for a companion AddOn's settings. With Dyre's Toolkit 2.17.0's
-- AddSettingsSection, the page shows the companion's own rows, which read and
-- write its live settings (John, 2026-11-26: "surface every setting in the
-- wrapped addon's settings, and just pass-through the setting to the wrapped
-- addon"). Without the companion's section (not loaded, or older), and with an
-- older Toolkit, the page has the link instead (AddSettingsLink: the button is
-- greyed while that AddOn has not joined the toolkit, and a click then says
-- what to install or enable; never in combat). While the companion is not
-- loaded, a primer box over the link says what it would add for a Mage (John,
-- 2026-11-27: "add a primer-text to tell people what they get if they install
-- it"); a Toolkit without AddSettingsPrimer draws none.
local SETTINGS_HOST = "MageToolsForever"

-- Toolkit 2.17.0's SETTINGS_SECTIONS_VERSION 3 (John, 2026-11-27: "the
-- top-level disable for each section should be on the top-level MTF panel"):
-- each companion's top switch (part "master") goes on MTF's top page, and the
-- rest (part "rest") on its own page, greyed while that switch is off. With
-- an older Toolkit, each page shows the whole section, as before.
local function SplitSections()
    local version = MTF.toolkit.SETTINGS_SECTIONS_VERSION
    return type(version) == "number" and version >= 3
end

-- One name per section (John, 2026-11-27: "let's have the same name used
-- consistently everywhere"): the owner's title (Toolkit 2.17.0's
-- SettingsSectionTitle) names the sub-page and the link, as it names the
-- owner's own heading and its top switch here; while the owner is missing or
-- older, the same word as a fallback.
local function SectionTitle(section)
    local title = type(MTF.toolkit.SettingsSectionTitle) == "function"
        and MTF.toolkit.SettingsSectionTitle(section.companion.addon, section.key)
    return type(title) == "string" and title ~= "" and title or section.title
end

local function AddSection(page, layout, section)
    local companion = section.companion
    local link = {addon = companion.addon, name = SectionTitle(section), button = section.button,
        tooltip = section.tooltip, missing = MTF.CompanionMessage(companion)}
    local toolkit = MTF.toolkit
    if type(toolkit.AddSettingsSection) == "function" then
        local primer = type(toolkit.AddSettingsPrimer) == "function" and MTF.COMPANION_PRIMERS[section.key] or nil
        toolkit.AddSettingsSection(page, layout, {addon = companion.addon, key = section.key, host = SETTINGS_HOST,
            link = link, primer = primer, part = SplitSections() and "rest" or nil})
    else
        toolkit.AddSettingsLink(page, layout, link)
    end
end

-- A page holds one or more sections; it is named after the first.
local function AddCompanionPage(parent, sections)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, SectionTitle(sections[1]))
    for _, section in ipairs(sections) do
        AddSection(page, layout, section)
    end
    return page
end

-- At most 400 characters each (the Toolkit's SETTINGS_PRIMER_MAX); a test checks.
MTF.COMPANION_PRIMERS = {
    shield = "Dyre's Shields Up shows your Ice Barrier, Mana Shield, Fire Ward, and Frost Ward as rings that "
        .. "drain as each shield wears down, with the amount left and an optional sound when one breaks. "
        .. "Install Dyre's Shields Up from CurseForge.",
    reminders = "Dyre's Buff Reminders shows an icon when Arcane Intellect, your armor, or Dampen or Amplify "
        .. "Magic is missing, and warns when your Arcane Powder runs low. Install Dyre's Buff Reminders "
        .. "from CurseForge.",
    chimes = "Dyre's Buff Reminders plays a sound just before Blink, Frost Nova, and your other important "
        .. "spells are ready again, so you know without watching your action bars. Install Dyre's Buff "
        .. "Reminders from CurseForge.",
    procs = "Dyre's Buff Reminders draws an arc on each side of your character and plays a sound when "
        .. "Missile Barrage, Fingers of Frost, or Clearcasting comes up. Install Dyre's Buff Reminders "
        .. "from CurseForge.",
    cues = "Dyre's Debuff Tracker shows an ice arc above your target's nameplate that fills with each stack "
        .. "of your Winter's Chill, and can play a note as the stacks go on. Install Dyre's Debuff Tracker "
        .. "from CurseForge.",
    control = "Dyre's Debuff Tracker shows a bar with the time left on your Polymorph, keeps a \"! Polymorph\" "
        .. "macro up to date, and can tell your group when you sheep a target. Install Dyre's Debuff Tracker "
        .. "from CurseForge.",
}

-- Every companion section, by key, with its fallback name and its link.
local SECTIONS = {
    shield = {companion = MTF.COMPANIONS[1], key = "shield", title = SHIELD_TITLE,
        button = "Open Shield settings",
        tooltip = "Opens Dyre's Shields Up, which shows your shields as rings that drain as they wear down."},
    reminders = {companion = MTF.COMPANIONS[2], key = "reminders", title = REMINDERS_TITLE,
        button = "Open Buff Reminders settings",
        tooltip = "Opens Dyre's Buff Reminders, which shows an icon when Arcane Intellect, your armor, or "
            .. "Dampen or Amplify Magic is missing."},
    chimes = {companion = MTF.COMPANIONS[2], key = "chimes", title = CHIMES_TITLE,
        button = "Open Buff Reminders settings",
        tooltip = "Opens Dyre's Buff Reminders, which plays a sound just before Blink, Frost Nova, and your "
            .. "other spells are ready."},
    -- John, 2026-11-27: "mage proc arcs from DBR are not in MTF, we should add a
    -- Procs panel". No filter: DBR shows the player's class's procs.
    procs = {companion = MTF.COMPANIONS[2], key = "procs", title = PROCS_TITLE,
        button = "Open Buff Reminders settings",
        tooltip = "Opens Dyre's Buff Reminders, which shows arcs and plays a sound for Missile Barrage, "
            .. "Fingers of Frost, and Clearcasting."},
    -- Dyre's Debuff Tracker's Winter's Chill, on the Procs page after the procs.
    cues = {companion = MTF.COMPANIONS[3], key = "cues", title = CUES_TITLE,
        button = "Open Debuff Tracker settings",
        tooltip = "Opens Dyre's Debuff Tracker, which shows the stacks of your Winter's Chill above your "
            .. "target's nameplate."},
    control = {companion = MTF.COMPANIONS[3], key = "control", title = POLYMORPH_TITLE,
        button = "Open Debuff Tracker settings",
        tooltip = "Opens Dyre's Debuff Tracker, which shows your Polymorph's time left and keeps your "
            .. "\"! Polymorph\" macro up to date."},
}

-- The pages, in order, each with its sections; the top switches follow the
-- same order. None for a companion that is not loaded (its page has the link
-- and the primer).
local COMPANION_PAGES = {
    {"shield"},
    {"reminders"},
    {"chimes"},
    {"procs", "cues"},
    {"control"},
}

local function AddCompanionMasters(page, layout)
    if not layout or not SplitSections() or type(MTF.toolkit.AddSettingsSection) ~= "function" then
        return
    end
    for _, keys in ipairs(COMPANION_PAGES) do
        for _, key in ipairs(keys) do
            MTF.toolkit.AddSettingsSection(page, layout, {addon = SECTIONS[key].companion.addon,
                key = key, host = SETTINGS_HOST, part = "master"})
        end
    end
end

local function AddCompanionPages(parent)
    for _, keys in ipairs(COMPANION_PAGES) do
        local sections = {}
        for _, key in ipairs(keys) do
            sections[#sections + 1] = SECTIONS[key]
        end
        AddCompanionPage(parent, sections)
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
        "%C is the count, %I the item (for Food & Water, both of them), %T the player's full name, and %D "
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
    local layout
    if MTF.toolkit then
        category, layout = MTF.toolkit.RegisterSettingsCategory(TITLE)
    end
    local ownCategory = category == nil
    if ownCategory then
        category, layout = Settings.RegisterVerticalLayoutCategory(TITLE)
    end
    Flag(category, "MTF_CONJURE_ENABLED", "Conjure bar", "conjure", "enabled", true,
        "A bar with water, food, and mana gem buttons: left-click uses or trades, right-click conjures.",
        RefreshConjure)
    Flag(category, "MTF_PORTALS_ENABLED", "Portal bar", "portals", "enabled", true,
        "A bar with a button for each teleport and portal you know, and the runes you carry for them.",
        RefreshPortals)
    AddCompanionMasters(category, layout)
    AddConjurePage(category)
    AddPortalsPage(category)
    AddCompanionPages(category)
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
