local addonName, MTF = ...

-- Polymorph bar (author-approved): one block in WTF's Bars format, the
-- sheeped mob's name above a bar that drains with the Polymorph's time left.
-- Only one Polymorph of yours can be up at a time, so there is one bar.
--
-- The tracking is Dyre's Toolkit's control engine (Control.lua,
-- CreateControlTracker; Toolkit 2.5.0, lead-approved engine split,
-- 2026-11-01), which holds the rules MTF 1.2.3 kept here: the mob locked as
-- the cast starts, the bar an aura slot bound to a unit (never mouseover),
-- forgotten when the mob dies, when your focus becomes another mob or none,
-- or after the longest Polymorph; the click recasts on your focus; and, on a
-- client without focus (Classic Era), the chain macro, the time left as text,
-- and no click. The Polymorph spells and the "! Polymorph" macro are the
-- Toolkit's ClassData.MAGE. Whether focus works is the Toolkit's one flag for
-- every Dyre's AddOn (FocusWorks).
--
-- MTF passes its saved settings, frame names, unit orders, look, and texts;
-- it owns the widget (place, size, scale), the settings, and the commands.
-- It claims the Mage's control bar, macro, and announcement at priority 10,
-- so with Dyre's Debuff Tracker also on, only MTF draws, writes, and says.
-- The moon comes only from the macro's /tm; nothing calls SetRaidTarget.

local CLASS = "MAGE"
local OWNER_PRIORITY = 10
-- WTF's Bars theme: the name line, then a bar line with an icon. The width,
-- the bar line's height, and the text size are settings (Core's
-- POLYMORPH_SIZE_SPECS); at the defaults the name line is 18, the icon 14.
local HEADER = 18
local ICON_INSET = 2
local PADDING = 6
local BAR_COLOR = {0.75, 0.45, 0.95}
-- Slider steps come quickly while a slider is dragged: the engine's slot is
-- rebuilt once, this long after the last (each build makes a new container).
local BUILD_DELAY = 0.2
local DEFAULT_POINT = {point = "CENTER", relativePoint = "CENTER", x = -260, y = 60}
local SAMPLE_NAME = "Polymorph (sample)"
local NAMES = {row = {"MageToolsForeverPolymorphBar"}, click = {"MageToolsForeverPolymorph"}}
-- With focus: your focus only. Without (MTF 1.2.3's chain, as the macro
-- casts): your focus, else the mob under the mouse when there is one, else
-- your target; an attackable mob, never a secret answer. The bar shows the
-- mob through your focus, your target, or its nameplate.
local FOCUS_LOCK = {units = {"focus"}}
local CHAIN_LOCK = {units = {"focus", "mouseover", "target"}, stopAt = {mouseover = true}}
local FIND_ORDER = {"focus", "target", "plates"}

local tracker
local buildKey, buildToken

-- The bar's sizes now, from its settings.
local function Sizes()
    local settings = MTF.db.polymorph
    local text = settings.textScale / 100
    local header = math.floor(HEADER * text + 0.5)
    local line = settings.height
    return {width = settings.width, header = header, line = line, icon = line - ICON_INSET, padding = PADDING,
        height = header + line + PADDING, text = text, alpha = settings.opacity / 100, color = BAR_COLOR,
        label = true}
end

-- What the engine's slot was built for: a change rebuilds it.
local function BuildKey(size)
    return string.format("%d:%d:%d:%d", size.width, size.line, math.floor(size.text * 100 + 0.5),
        math.floor(size.alpha * 100 + 0.5))
end

-- A setting change: the rows' look at once, also in combat, and one rebuild
-- of the engine slot after the slider rests (the engine waits out combat).
local function ScheduleBuild()
    tracker:ApplyLook()
    local token = {}
    buildToken = token
    C_Timer.After(BUILD_DELAY, function()
        if buildToken == token then
            buildKey = BuildKey(Sizes())
            tracker:Rebuild()
        end
    end)
end

local function ShowTooltip(holder)
    GameTooltip:SetOwner(holder, "ANCHOR_TOP")
    if holder.spellName then
        GameTooltip:SetText("Click: " .. holder.spellName .. " your focus again.", 1, 1, 1)
    elseif not MTF.toolkit.FocusWorks() then
        GameTooltip:SetText("Sheep again with \"! Polymorph\": mouse over the mob, or target it.",
            0.7, 0.7, 0.7, 1, true)
    else
        GameTooltip:SetText("Sheep a mob with \"! Polymorph\", then click here to sheep your focus again.",
            0.7, 0.7, 0.7, 1, true)
    end
    GameTooltip:Show()
end

-- The engine reads `store` live: MTF's db.polymorph, whose macro switch is
-- saved as "macro" (the engine's "macros").
local store = setmetatable({}, {__index = function(_, key)
    local settings = MTF.db.polymorph
    if key == "macros" then
        return settings.macro
    end
    return settings[key]
end})

local function CreateTracker()
    local toolkit = MTF.toolkit
    local created, missing = toolkit.CreateControlTracker({
        addon = addonName, priority = OWNER_PRIORITY, class = CLASS, store = store, names = NAMES, rows = 1,
        look = Sizes,
        locked = function() return MTF.db.locked end,
        samples = {SAMPLE_NAME},
        find = FIND_ORDER,
        lock = CHAIN_LOCK,
        focusLock = FOCUS_LOCK,
        countdown = true,
        clickThrough = true,
        markerFor = function(key)
            local marker
            for _, def in ipairs(toolkit.ClassSpells(CLASS).control) do
                if def.key == key then
                    marker = def.marker
                end
            end
            return MTF.db.polymorph.mark and marker or nil
        end,
        announce = {
            text = function() return MTF.db.announce.polymorphGroupText end,
            -- As MTF 1.2.3: only while the bar is on.
            enabled = function() return MTF.db.announce.polymorphGroup and MTF.db.polymorph.enabled end,
        },
        keeper = {owned = MTF.db.ownedMacros, warn = MTF.Report},
        tooltip = ShowTooltip,
    })
    return created, missing
end

-- The holder is a Dyre's Toolkit widget: the toolkit places, drags, snaps,
-- outlines, saves, and sizes it (its frame size from the bar's settings,
-- through measure), with Bar size as its scale and the sliders on the
-- Polymorph page. Existing saves carry over: the bar line's height is saved
-- as "height", which the toolkit reserves for a frame height, so the setting
-- is named barHeight. Its mouse is the engine's: clicks only with a sheep to
-- click or while unlocked (clickThrough).
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
    buildKey = BuildKey(size)
    MTF.polymorphWidget = MTF.toolkit.CreateWidget({
        addon = addonName, key = "polymorph", title = "Polymorph", frame = tracker.rows[1].holder,
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
            tracker:SetScale(scale)
            if BuildKey(Sizes()) ~= buildKey then
                ScheduleBuild()
            end
        end,
        onOpacity = function()
            if BuildKey(Sizes()) ~= buildKey then
                ScheduleBuild()
            end
        end,
    })
end

function MTF.InitializePolymorph()
    local missing
    tracker, missing = CreateTracker()
    if not tracker then
        MTF.Report("The Polymorph bar stays off: this client lacks " .. tostring(missing) .. ".")
        return
    end
    MTF.polymorphTracker = tracker
    MTF.polymorphBar = tracker.rows[1]
    CreateWidget()
end

-- Settings or the lock changed: the bar, its click, and the macro follow.
function MTF.RefreshPolymorph()
    if tracker then
        tracker:Refresh()
    end
end

-- Out of combat only (else when combat ends); turning the macro off deletes it.
function MTF.ApplyPolymorphMacro()
    if tracker then
        tracker:ApplyMacros()
    end
end

-- /mtf debug_polymorph: the engine's lines (IDs, last cast, row, click).
function MTF.ReportPolymorphDebug()
    MTF.Report(string.format("debug_polymorph available=%s known=%s engine=%s", tostring(tracker ~= nil),
        tostring(tracker ~= nil and tracker:KnowsAny()), tostring(MTF.toolkit.AuraEngineKind())))
    if not tracker then
        return
    end
    for _, line in ipairs(tracker:DebugLines()) do
        MTF.Report("debug_polymorph " .. line)
    end
    MTF.Report("debug_polymorph moon=" .. (MTF.db.polymorph.mark and "from the macro" or "off"))
end

-- /mtf debug_focus: what the Toolkit learned about the focus on this client.
function MTF.ReportFocusDebug()
    local works = MTF.toolkit.FocusWorks()
    local exists = UnitExists("focus")
    MTF.Report(string.format("debug_focus focusWorks=%s focusNow=%s macro=%s click=%s", tostring(works),
        MTF.Describe(exists), works and "focus" or "focus, mouseover, target",
        works and "on" or "off (no focus seen)"))
end

-- /mtf reset_focus: the Toolkit's reset, for every Dyre's AddOn; the chain
-- macro comes back until a focus is seen again (macros and clicks wait out
-- combat).
function MTF.ResetFocus()
    MTF.toolkit.ResetFocusWorks()
    MTF.Report(MTF.toolkit.FOCUS_RESET_TEXT)
end
