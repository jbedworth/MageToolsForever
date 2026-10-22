local _, MTF = ...

-- The AddOn settings: a main page with one switch per module, and a subpage
-- per module for its details, in Blizzard's vertical layout with proxy
-- settings that read and write MageToolsForeverDB directly. The Shield, Buff
-- Reminders, and Cooldown Chimes pages link to Dyre's Shields Up's and Dyre's
-- Buff Reminders' own settings (author, 1.2.0: linked, not mirrored).
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

local function RefreshPortals()
    MTF.RefreshPortals()
end

local function RefreshPolymorph()
    MTF.RefreshPolymorph()
end

-- A widget's size sliders (Dyre's Toolkit: each with a gold mark at its
-- default, then "Reset size"), with the label players know.
local function AddWidgetSizes(page, layout, widget, tooltips, resetTooltip)
    if widget then
        MTF.toolkit.AddWidgetSettings(page, layout, widget,
            {labels = {scale = "Bar size", width = "Bar width"}, tooltips = tooltips, resetTooltip = resetTooltip})
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
    }, "Back to the bar's own width, height, and text size. Bar size and Opacity stay as they are.")
end

-- A page that links to a companion AddOn's settings (Dyre's Toolkit's
-- AddSettingsLink: the button is greyed while that AddOn has not joined the
-- toolkit, and a click then says what to install or enable; never in combat).
local function AddLinkPage(parent, title, companion, name, button, tooltip)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, title)
    MTF.toolkit.AddSettingsLink(page, layout, {addon = companion.addon, name = name, button = button,
        tooltip = tooltip, missing = MTF.CompanionMessage(companion)})
    return page
end

local function AddLinkPages(parent)
    local shields, reminders = MTF.COMPANIONS[1], MTF.COMPANIONS[2]
    AddLinkPage(parent, SHIELD_TITLE, shields, "Shield display", "Open Shield settings",
        "Dyre's Shields Up draws the shield display for every class. Open its settings.")
    AddLinkPage(parent, REMINDERS_TITLE, reminders, "Buff reminders", "Open Buff Reminders settings",
        "Dyre's Buff Reminders shows Arcane Intellect, your armor, and Dampen or Amplify Magic for every class. "
            .. "Open its settings.")
    AddLinkPage(parent, CHIMES_TITLE, reminders, "Cooldown chimes", "Open Buff Reminders settings",
        "Dyre's Buff Reminders plays a sound just before Blink, Frost Nova, and your other spells are ready. "
            .. "Open its settings.")
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
    AddConjurePage(category)
    AddPortalsPage(category)
    AddPolymorphPage(category)
    AddLinkPages(category)
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
