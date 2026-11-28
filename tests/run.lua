-- Run from the repository root: lua tests/run.lua
-- These mocks test AddOn logic, not Forever compatibility, protected actions,
-- secret-value behavior, layout, or taint.
-- Every test gets its own globals, bags, cursor, clock, event frames, and namespace.
if _VERSION ~= "Lua 5.1" then
    io.stderr:write("This suite requires Lua 5.1; found " .. tostring(_VERSION) .. "\n")
    os.exit(1)
end

local tests = {}
local function test(name, body)
    tests[#tests + 1] = {name = name, body = body}
end
local function equal(actual, expected, context)
    if actual ~= expected then
        error((context or "value") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end
local function contains(actual, fragment, context)
    if type(actual) ~= "string" or not actual:find(fragment, 1, true) then
        error((context or "text") .. ": expected text containing " .. fragment
            .. ", got " .. tostring(actual), 2)
    end
end

local TOOLKIT_FILES = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Profiles.lua", "Auras.lua", "Units.lua",
    "HealthBars.lua", "Spells.lua", "Macros.lua", "Announce.lua", "ClassData.lua", "Owners.lua", "Control.lua"}
-- The real Dyre's Toolkit beside this repository when it is there; else (as
-- in CI, which has only this repository) the copy in tests/toolkit.
local TOOLKIT_DIR = "tests/toolkit/"
do
    local probe = io.open("../DyresToolkit/Core.lua", "rb")
    if probe then
        probe:close()
        TOOLKIT_DIR = "../DyresToolkit/"
    end
end
print("Dyre's Toolkit from " .. TOOLKIT_DIR)
local RUNTIME_FILES = {"Commands.lua", "Core.lua", "Conjure.lua", "Portals.lua", "Options.lua"}
local SPELLS = {
    [5504] = "Conjure Water", [5505] = "Conjure Water", [5506] = "Conjure Water", [6127] = "Conjure Water",
    [587] = "Conjure Food", [597] = "Conjure Food", [990] = "Conjure Food", [6129] = "Conjure Food",
    [759] = "Conjure Mana Agate", [3552] = "Conjure Mana Jade",
    [1953] = "Blink", [122] = "Frost Nova", [865] = "Frost Nova", [2139] = "Counterspell",
    [11958] = "Ice Block", [11426] = "Ice Barrier", [13031] = "Ice Barrier", [1463] = "Mana Shield",
    [8494] = "Mana Shield", [12051] = "Evocation", [12472] = "Cold Snap", [543] = "Fire Ward",
    [6143] = "Frost Ward", [120] = "Cone of Cold", [2136] = "Fire Blast", [12043] = "Presence of Mind",
    [12042] = "Arcane Power", [11129] = "Combustion", [133] = "Fireball",
    [3561] = "Teleport: Stormwind", [3562] = "Teleport: Ironforge", [3565] = "Teleport: Darnassus",
    [118] = "Polymorph", [12826] = "Polymorph", [28272] = "Polymorph: Pig",
    [1459] = "Arcane Intellect", [23028] = "Arcane Brilliance", [168] = "Frost Armor", [7302] = "Ice Armor",
    [6117] = "Mage Armor", [604] = "Dampen Magic",
    [10059] = "Portal: Stormwind", [11416] = "Portal: Ironforge", [11419] = "Portal: Darnassus"}
-- Conjured items: name and required level, as Classic has them.
local ITEMS = {[5350] = {"Conjured Water", 1}, [2288] = {"Conjured Fresh Water", 5},
    [2136] = {"Conjured Purified Water", 15}, [3772] = {"Conjured Spring Water", 25},
    [5349] = {"Conjured Muffin", 1}, [1113] = {"Conjured Bread", 5}, [1114] = {"Conjured Rye", 15},
    [1487] = {"Conjured Pumpernickel", 25}, [5514] = {"Mana Agate", 1}, [5513] = {"Mana Jade", 1},
    [17031] = {"Rune of Teleportation", 20}, [17032] = {"Rune of Portals", 40}}
local WATER_SPRING, WATER_PURIFIED, WATER_FRESH = 3772, 2136, 2288
local FOOD_RYE = 1114
local FIREBALL = 133

-- A secret stands in for the client's opaque combat values; tests mark them with
-- issecretvalue, and any comparison or concatenation with one raises an error.
local function secret()
    return setmetatable({}, {
        __eq = function() error("compared a secret value") end,
        __lt = function() error("compared a secret value") end,
        __le = function() error("compared a secret value") end,
        __concat = function() error("concatenated a secret value") end,
        __tostring = function() error("printed a secret value") end,
        __index = function() error("indexed a secret value") end,
    })
end

local function fixture(options)
    options = options or {}
    local state = {frames = {}, messages = {}, now = 100, combat = false, cursor = nil,
        deleteBlocked = false, secrets = {}, settings = {}, categories = {}, opened = nil,
        notified = {}, known = options.known or {}, carried = options.carried or {}, sent = {},
        group = options.group, tooltip = {}}
    -- bags[bag] = {size, family, items = {[slot] = {itemID, stackCount, isLocked}}}
    state.bags = options.bags or {
        [0] = {size = 16, family = 0, items = {}},
        [1] = {size = 10, family = 0, items = {}},
        [2] = {size = 0, family = 0, items = {}},
        [3] = {size = 0, family = 0, items = {}},
        [4] = {size = 0, family = 0, items = {}},
    }
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.SlashCmdList = options.slashCmdList or {}
    for key, value in pairs(options.globals or {}) do env[key] = value end
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message)
        state.messages[#state.messages + 1] = message
    end}
    state.toc = {}
    for text in io.lines("MageToolsForever.toc") do
        local key, value = text:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then state.toc[key] = value end
    end
    -- MTF reads its own fields by folder name; the toolkit reads other
    -- AddOns' Group (its owner claims are for Dyre's AddOns only).
    env.C_AddOns = {GetAddOnMetadata = function(name, field)
        if name ~= "MageToolsForever" then
            equal(field, "Group", "metadata of another AddOn")
            return (options.family or {})[name] and "DyresToolkit" or nil
        end
        return state.toc[field] or ""
    end}
    env.CreateSettingsButtonInitializer = function(name, buttonText, onClick, tooltip)
        local object = {button = true, name = name, buttonText = buttonText, onClick = onClick, tooltip = tooltip,
            modifyPredicates = {}}
        function object:AddModifyPredicate(predicate) self.modifyPredicates[#self.modifyPredicates + 1] = predicate end
        return object
    end
    env.CreateSettingsListSectionHeaderInitializer = function(name, tooltip)
        return {heading = name, tooltip = tooltip}
    end
    env.UnitClass = function(unit)
        if unit ~= "player" then
            local data = state.units[unit]
            if data then return data.class, data.class end
            return
        end
        local class = options.class or "MAGE"
        return class:sub(1, 1) .. class:sub(2):lower(), class
    end
    env.GetTime = function() return state.now end
    env.InCombatLockdown = function() return state.combat end
    env.NUM_BAG_SLOTS = 4
    if options.reagentBag then
        env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    end
    env.issecretvalue = function(value) return state.secrets[value] == true end
    env.C_Spell = {GetSpellName = function(id)
        if SPELLS[id] then return SPELLS[id] end
    end}
    env.C_Item = {
        -- As in client, the count covers every carried stack.
        GetItemCount = function(id)
            local total = state.carried[id] or 0
            for bag = 0, 4 do
                for _, entry in pairs(state.bags[bag].items) do
                    if entry.itemID == id then total = total + entry.stackCount end
                end
            end
            return total
        end,
        -- As in client, uncached item data returns nothing.
        GetItemInfo = function(id)
            local info = ITEMS[id]
            if info then return info[1], "link", 1, 10, info[2] end
        end,
        GetItemIconByID = function(id) return 1000 + id end,
        RequestLoadItemDataByID = function(id) state.requested = (state.requested or 0) + 1 end,
    }
    env.C_SpellBook = {}
    if not options.noSpellBook then
        env.C_SpellBook.IsSpellKnown = function(id) return state.known[id] == true end
    end
    state.timers = {}
    env.C_Timer = {After = function(seconds, callback)
        state.timers[#state.timers + 1] = {at = state.now + seconds, callback = callback}
    end}
    function state.runTimers()
        local due = {}
        for index = #state.timers, 1, -1 do
            if state.timers[index].at <= state.now then
                due[#due + 1] = table.remove(state.timers, index)
            end
        end
        for _, timer in ipairs(due) do timer.callback() end
    end
    env.C_XMLUtil = {GetTemplateInfo = function(name)
        if name == "CustomAuraContainerTemplate" and not options.noAuraContainer then return {} end
    end}
    env.C_AddOns.IsAddOnLoaded = function(name) return state.loadedAddOns and state.loadedAddOns[name] end
    -- As the client: reason "MISSING" when an AddOn is not installed, and
    -- "DISABLED" when it is installed but turned off (options.disabledAddOns).
    env.C_AddOns.GetAddOnInfo = function(name)
        if state.loadedAddOns and state.loadedAddOns[name] then
            return name, name, "", true, nil
        end
        if state.disabledAddOns and state.disabledAddOns[name] then
            return name, name, "", false, "DISABLED"
        end
        return name, nil, nil, false, "MISSING"
    end
    env.C_AddOns.LoadAddOn = function(name)
        state.loadedAddOns = state.loadedAddOns or {}
        state.loadedAddOns[name] = true
    end
    env.C_Spell.GetSpellTexture = function(id) return 2000 + id end
    -- As on Forever, conjure spells have numeric ranks.
    local RANKS = {[5504] = 1, [5505] = 2, [5506] = 3, [6127] = 4, [587] = 1, [597] = 2, [990] = 3, [6129] = 4,
        [759] = 1, [3552] = 1}
    env.C_Spell.GetSpellSubtext = function(id) if RANKS[id] then return "Rank " .. RANKS[id] end end
    -- The spellbook: one skill line holding state.spellbook entries {spellID, name}.
    state.spellbook = options.spellbook or {}
    env.C_SpellBook = env.C_SpellBook or {}
    env.C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
    env.C_SpellBook.GetSpellBookSkillLineInfo = function()
        return {itemIndexOffset = 0, numSpellBookItems = #state.spellbook}
    end
    -- As in client, each item has a type: 1 learned, 2 learned later (FutureSpell).
    env.C_SpellBook.GetSpellBookItemInfo = function(index)
        local item = state.spellbook[index]
        if item then
            return {spellID = item.spellID, name = item.name, itemType = item.itemType or 1}
        end
    end
    env.Enum = env.Enum or {}
    env.Enum.SpellBookSpellBank = {Player = 0}
    env.Enum.SpellBookItemType = {None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4}
    env.Enum.StatusBarTimerDirection = {ElapsedTime = 0, RemainingTime = 1}
    -- options.classic: Classic Era and Anniversary, as their 1.15.9 and 2.5.6
    -- sources show: no aura engine (Blizzard_AuraContainer), no spellbook skill
    -- lines, and aura reads that work in combat.
    if options.classic then
        options.noAuraContainer = true
        env.C_SpellBook.GetNumSpellBookSkillLines = nil
        env.C_SpellBook.GetSpellBookSkillLineInfo = nil
        env.C_SpellBook.GetSpellBookItemInfo = nil
    end
    env.UnitIsDead = function(unit) return state.units[unit] ~= nil and state.units[unit].dead == true end
    env.UnitIsDeadOrGhost = function(unit) return state.units[unit] ~= nil and state.units[unit].dead == true end
    env.UnitIsConnected = function(unit) return state.units[unit] ~= nil end
    env.UnitIsVisible = function(unit) return state.units[unit] ~= nil and state.units[unit].far ~= true end
    -- Raid markers, by unit's GUID.
    state.marks = {}
    -- As on Forever, the marker index is secret in combat.
    env.GetRaidTargetIndex = function(unit)
        if state.combat then
            local value = secret()
            state.secrets[value] = true
            return value
        end
        local data = state.units[unit]
        return data and state.marks[data.guid or data.name]
    end
    -- As in client (BugGrabber, 0.3.3): AddOn code may never call it.
    env.SetRaidTarget = function()
        state.markCount = (state.markCount or 0) + 1
        error("ADDON_ACTION_FORBIDDEN SetRaidTarget")
    end
    -- State drivers: "[@unit,harm,nodead] show; hide", evaluated by the game.
    state.drivers = {}
    function state.applyDrivers()
        for frame, driver in pairs(state.drivers) do
            if driver == "[combat] hide; show" then
                frame.shown = not state.combat
            elseif driver == "show" or driver == "hide" then
                frame.shown = driver == "show"
            else
                local unit = driver:match("@(%a+)")
                local data = state.units[unit]
                frame.shown = data ~= nil and not data.friend and not data.dead
            end
        end
    end
    env.RegisterStateDriver = function(frame, kind, driver)
        equal(kind, "visibility")
        if state.combat then error("RegisterStateDriver in combat") end
        state.drivers[frame] = driver
        state.applyDrivers()
    end
    env.UnregisterStateDriver = function(frame, kind)
        equal(kind, "visibility")
        if state.combat then error("UnregisterStateDriver in combat") end
        state.drivers[frame] = nil
    end
    -- The trade window: six slots; placing an item may need a key press or click.
    state.tradeSlots = {}
    env.InitiateTrade = function(unit) state.tradeWith = unit end
    env.GetTradePlayerItemLink = function(slot)
        if state.tradeSlots[slot] then return "item:" .. state.tradeSlots[slot].itemID end
    end
    env.ClickTradeButton = function(slot)
        if state.tradeNeedsHardware and not state.hardware then
            state.emit("ADDON_ACTION_BLOCKED", "MageToolsForever", "UNKNOWN()")
            return
        end
        if state.cursor then
            -- As in client, a trade slot holds a bag slot: a split dropped in
            -- trades the whole stack it came from.
            local count = state.cursor.count
            if state.cursor.split then
                local source = state.bags[state.cursor.bag].items[state.cursor.slot]
                count = count + (source and source.stackCount or 0)
            end
            state.tradeSlots[slot] = {itemID = state.cursor.itemID, count = count}
            state.cursor = nil
        end
    end
    function state.traded(itemID)
        local total = 0
        for _, entry in pairs(state.tradeSlots) do
            if entry.itemID == itemID then total = total + entry.count end
        end
        return total
    end
    env.IsInInstance = function() return state.inInstance == true end
    state.macros = options.macros or {}
    -- As in client, the global exists only once the Macro window has loaded.
    env.Constants = {MacroConsts = {MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30}}
    local function macroIndex(name)
        for index, macro in ipairs(state.macros) do
            if macro.name == name then return 120 + index end
        end
        return 0
    end
    env.GetMacroIndexByName = macroIndex
    env.GetNumMacros = function() return 0, #state.macros end
    env.GetMacroBody = function(index) return state.macros[index - 120].body end
    env.CreateMacro = function(name, icon, body, perCharacter)
        if state.combat then error("CreateMacro in combat") end
        equal(perCharacter, true, "a character macro")
        state.macros[#state.macros + 1] = {name = name, icon = icon, body = body}
        return 120 + #state.macros
    end
    env.EditMacro = function(index, name, icon, body)
        if state.combat then error("EditMacro in combat") end
        state.macros[index - 120] = {name = name, icon = icon, body = body}
        state.macroEdits = (state.macroEdits or 0) + 1
    end
    env.DeleteMacro = function(index)
        if state.combat then error("DeleteMacro in combat") end
        table.remove(state.macros, index - 120)
    end
    env.PlaySoundFile = function(file, channel) state.played = {file = file, channel = channel} end
    state.errors = {}
    env.UIErrorsFrame = {AddMessage = function(_, message) state.errors[#state.errors + 1] = message end}
    env.SOUNDKIT = {MAP_PING = 3175, TELL_MESSAGE = 3081, IG_PLAYER_INVITE = 880, READY_CHECK = 8960,
        RAID_WARNING = 8959, UI_ORDERHALL_TALENT_READY_TOAST = 73280}
    state.sounds = {}
    env.PlaySound = function(kit, channel) state.sounds[#state.sounds + 1] = {kit = kit, channel = channel} end
    -- Dyre's Sounds, faked with a few sounds of each kind (the library has its
    -- own suite): every sound it plays lands in state.sounds by key. Text to
    -- Speech plays only with state.voice. options.noSounds leaves it out, and
    -- options.oldSounds offers an older contract.
    state.loadedAddOns = options.loadedAddOns
    state.disabledAddOns = options.disabledAddOns
    if not options.noSounds then
        local order = {
            {key = "fadingslow", label = "Dyre's Picks: Fading slow disappear", file = "FadingSlowDisappear.mp3"},
            {key = "cartoonvanish", label = "Dyre's Picks: Cartoon vanish", file = "CartoonVanish.mp3"},
            {key = "magical", label = "Dyre's Picks: Magical disappear", file = "MagicalDisappear.mp3"},
            {key = "talent", label = "Interface: Talent ready", kit = "UI_ORDERHALL_TALENT_READY_TOAST"},
            {key = "alarm", label = "Interface: Alarm clock", kit = "ALARM_CLOCK_WARNING_2"},
            {key = "shortbellstrike", label = "Short: Bell Strike", id = 353392},
            {key = "impactspopclick", label = "Impacts: Pop Click", id = 316434},
            {key = "impspell", label = "Imp: Spell chirp", fileID = 639156},
            {key = "voice", label = "Text to Speech", voice = true},
        }
        local catalog = {}
        for _, sound in ipairs(order) do catalog[sound.key] = sound end
        local aliases = {popclick = "impactspopclick", effectmagical = "magical", effectfadingslow = "fadingslow"}
        local library = {}
        function library.RequireContract(minimum)
            if not options.oldSounds and minimum <= 1 then return library end
        end
        function library.Resolve(key)
            key = aliases[key] or key
            return catalog[key] and key or nil
        end
        function library.Label(key)
            local sound = catalog[library.Resolve(key) or ""]
            return sound and sound.label
        end
        function library.AuraSound(key)
            local sound = catalog[library.Resolve(key) or ""]
            if sound and sound.file then
                return {soundFileName = "Interface\\AddOns\\DyresSounds\\Sounds\\" .. sound.file}
            elseif sound and sound.fileID then
                return {soundFileID = sound.fileID}
            end
        end
        function library.List(filter)
            local list = {}
            for _, sound in ipairs(order) do
                if filter ~= "aura" or library.AuraSound(sound.key) then list[#list + 1] = sound end
            end
            return list
        end
        function library.Groups(filter)
            local groups, byName = {}, {}
            for _, sound in ipairs(library.List(filter)) do
                local group = sound.label:match("^(.-): ") or sound.label
                if not byName[group] then
                    byName[group] = {name = group, sounds = {}}
                    groups[#groups + 1] = byName[group]
                end
                table.insert(byName[group].sounds, sound)
            end
            return groups
        end
        function library.Play(key, speech, channel)
            local sound = catalog[library.Resolve(key) or ""]
            if not sound or (sound.voice and (not state.voice or type(speech) ~= "string")) then return false end
            state.sounds[#state.sounds + 1] = {key = sound.key, speech = speech, channel = channel}
            return true
        end
        function library.Choices(filter)
            return function()
                local list = {}
                for _, sound in ipairs(library.List(filter)) do
                    list[#list + 1] = {value = sound.key, label = sound.label}
                end
                return list
            end
        end
        function library.SetupMenu(initializer, filter) initializer.soundMenu = filter or "all" end
        env.DyresSounds = library
    end
    -- Cooldowns: secret in combat, as the client's GetSpellCooldown is.
    state.cooldowns = {}
    env.C_Spell.GetSpellCooldown = function(id)
        local cooldown = state.cooldowns[id]
        if not cooldown then return {startTime = 0, duration = 0, isEnabled = true} end
        if state.combat then
            local start, duration = secret(), secret()
            state.secrets[start], state.secrets[duration] = true, true
            return {startTime = start, duration = duration, isEnabled = true}
        end
        return {startTime = cooldown.start, duration = cooldown.duration, isEnabled = true}
    end
    -- Absorbs: always secret, as the client's UnitGetTotalAbsorbs is.
    state.absorb = secret()
    state.secrets[state.absorb] = true
    state.maxHealth = 1500
    env.UnitGetTotalAbsorbs = function(unit) equal(unit, "player") return state.absorb end
    env.UnitHealthMax = function(unit) equal(unit, "player") return state.maxHealth end
    env.AbbreviateNumbers = function(value) return {abbreviated = value} end
    -- Wall-clock seconds, as WoW's time().
    env.time = function() return 1000000 + math.floor(state.now) end
    env.IsInRaid = function() return state.group == "raid" end
    env.IsInGroup = function() return state.group ~= nil end
    env.GetZoneText = function() return state.zone or "Redridge Mountains" end
    env.C_ChatInfo = {SendChatMessage = function(message, chatType, _, target)
        -- As in client, an emote outside a key press or click is blocked.
        if (chatType == "SAY" and state.sayBlocked) or (chatType == "EMOTE" and not state.hardware) then
            state.emit("ADDON_ACTION_BLOCKED", "MageToolsForever", "UNKNOWN()")
            return
        end
        state.sent[#state.sent + 1] = {message = message, chatType = chatType, target = target}
    end}
    env.hooksecurefunc = function(target, name, hook)
        local original = target[name]
        target[name] = function(...)
            local result = original(...)
            hook(...)
            return result
        end
    end
    -- As the client (BugGrabber, 1.3.0: "bad argument #5 to 'SetText'"): the
    -- color is numbers; SetText takes an alpha before its wrap, AddLine does not.
    local function checkColor(method, r, g, b)
        for index, value in ipairs({r or 0, g or 0, b or 0}) do
            if type(value) ~= "number" then
                error("bad argument #" .. (index + 1) .. " to '" .. method .. "'", 3)
            end
        end
    end
    env.GameTooltip = {
        SetOwner = function(_, owner, anchor) state.tooltip = {owner = owner, anchor = anchor} end,
        SetText = function(_, text, r, g, b, alpha, wrap)
            checkColor("SetText", r, g, b)
            if alpha ~= nil and (type(alpha) ~= "number" or alpha < 0 or alpha > 1) then
                error("bad argument #5 to 'SetText' (outside of expected range)", 2)
            end
            if wrap ~= nil and type(wrap) ~= "boolean" then
                error("bad argument #6 to 'SetText'", 2)
            end
            state.tooltip[#state.tooltip + 1] = text
        end,
        AddLine = function(_, text, r, g, b, wrap)
            checkColor("AddLine", r, g, b)
            if wrap ~= nil and type(wrap) ~= "boolean" then
                error("bad argument #5 to 'AddLine'", 2)
            end
            state.tooltip[#state.tooltip + 1] = text
        end,
        Show = function() end,
        Hide = function() end,
    }

    -- Containers and the cursor. As in client, an empty slot reports nothing.
    local function item(bag, slot)
        local container = state.bags[bag]
        return container and container.items[slot]
    end
    env.C_Container = {
        GetContainerNumSlots = function(bag) return state.bags[bag] and state.bags[bag].size or 0 end,
        GetContainerNumFreeSlots = function(bag)
            local container = state.bags[bag]
            local used = 0
            for _ in pairs(container.items) do used = used + 1 end
            return container.size - used, container.family
        end,
        GetContainerItemID = function(bag, slot)
            local entry = item(bag, slot)
            if entry then return entry.itemID end
        end,
        GetContainerItemInfo = function(bag, slot)
            local entry = item(bag, slot)
            if not entry then return end
            return {itemID = entry.itemID, stackCount = entry.stackCount, isLocked = entry.isLocked == true}
        end,
        PickupContainerItem = function(bag, slot)
            local entry = item(bag, slot)
            -- With an item on the cursor, an empty slot takes it.
            if state.cursor and not entry and slot <= state.bags[bag].size then
                -- The server confirms the move later; until then the slot is locked.
                state.bags[bag].items[slot] = {itemID = state.cursor.itemID, stackCount = state.cursor.count,
                    isLocked = state.lockMoves == true}
                state.cursor = nil
                state.emit("CURSOR_CHANGED")
                return
            end
            -- With the same item on the cursor, the stacks merge.
            if state.cursor and entry and entry.itemID == state.cursor.itemID and not entry.isLocked then
                entry.stackCount = entry.stackCount + state.cursor.count
                state.cursor = nil
                state.emit("CURSOR_CHANGED")
                return
            end
            -- As in client, a locked slot cannot be picked up.
            if state.cursor or not entry or entry.isLocked then return end
            state.bags[bag].items[slot] = nil
            state.cursor = {itemID = entry.itemID, count = entry.stackCount, bag = bag, slot = slot}
            state.emit("CURSOR_CHANGED")
        end,
        SplitContainerItem = function(bag, slot, amount)
            local entry = item(bag, slot)
            if state.cursor or not entry or entry.stackCount <= amount then return end
            entry.stackCount = entry.stackCount - amount
            state.cursor = {itemID = entry.itemID, count = amount, bag = bag, slot = slot, split = true}
            state.emit("CURSOR_CHANGED")
        end,
    }
    env.GetCursorInfo = function()
        if state.cursor then return "item", state.cursor.itemID end
    end
    env.ClearCursor = function()
        local cursor = state.cursor
        if not cursor then return end
        local entry = item(cursor.bag, cursor.slot)
        if entry then
            entry.stackCount = entry.stackCount + cursor.count
        else
            state.bags[cursor.bag].items[cursor.slot] = {itemID = cursor.itemID, stackCount = cursor.count}
        end
        state.cursor = nil
        state.emit("CURSOR_CHANGED")
    end
    -- In client, DeleteCursorItem outside a key press or click raised
    -- ADDON_ACTION_BLOCKED (UNKNOWN()) and left the item on the cursor.
    env.DeleteCursorItem = function()
        if state.deleteBlocked or not state.hardware or (state.combat and state.combatDeleteBlocked) then
            state.emit("ADDON_ACTION_BLOCKED", "MageToolsForever", "UNKNOWN()")
            return
        end
        if not state.cursor then return end
        state.deleted = (state.deleted or 0) + state.cursor.count
        state.cursor = nil
        state.emit("CURSOR_CHANGED")
    end

    -- Units, auras, and restrictions for the probe.
    state.units = options.units or {}
    state.units.player = state.units.player or {name = "Dyre", player = true, friend = true, level = 20}
    env.UnitExists = function(unit) return state.units[unit] ~= nil end
    env.UnitFullName = function(unit)
        local data = state.units[unit]
        if data then return data.name, data.surname or (unit == "player" and "Maebryn" or nil) end
    end
    env.UnitIsPlayer = function(unit) return state.units[unit] ~= nil and state.units[unit].player == true end
    env.UnitIsFriend = function(_, unit) return state.units[unit] ~= nil and state.units[unit].friend == true end
    env.UnitLevel = function(unit) return state.units[unit] and state.units[unit].level or 0 end
    -- As in client, UnitName returns the first and the last name (Forever full names).
    env.UnitName = function(unit)
        local data = state.units[unit]
        if data then return data.name, data.surname end
    end
    -- state.secretGUIDs[token]: that token's GUID is secret, as in some combat cases.
    state.secretGUIDs = {}
    env.UnitGUID = function(unit)
        if state.units[unit] and state.secretGUIDs[unit] then
            local value = secret()
            state.secrets[value] = true
            return value
        end
        return state.units[unit] and state.units[unit].guid
    end
    env.UnitCanAttack = function(_, unit)
        local data = state.units[unit]
        if data and data.secretAttack then
            local value = secret()
            state.secrets[value] = true
            return value
        end
        return data ~= nil and not data.friend
    end
    env.UnitIsUnit = function(a, b) return state.units[a] == state.units[b] end
    -- In client, combat makes index access raise an error for AddOn code.
    local function auras(unit, filter)
        equal(filter, "HARMFUL|PLAYER")
        local data = state.units[unit]
        return data and data.auras or {}
    end
    local function byInstance(unit, id)
        for _, aura in ipairs(auras(unit, "HARMFUL|PLAYER")) do
            if aura.auraInstanceID == id then return aura end
        end
    end
    env.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
            if state.auraIndexRefused then
                error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'MageToolsForever'")
            end
            return auras(unit, filter)[index]
        end,
        GetUnitAuraInstanceIDs = function(unit, filter)
            local ids = {}
            for index, aura in ipairs(auras(unit, filter)) do ids[index] = aura.auraInstanceID end
            return ids
        end,
        GetAuraDataByAuraInstanceID = byInstance,
        GetAuraDuration = function(unit, id)
            local aura = byInstance(unit, id)
            if not aura then return end
            return {
                HasSecretValues = function() return state.secrets[aura.expirationTime] == true end,
                GetRemainingDuration = function() return aura.remaining end,
            }
        end,
        GetUnitAuras = function(unit, filter) return auras(unit, filter) end,
        -- As in client, aura sound changes are refused during an encounter.
        AddAuraSound = function(trigger, info)
            if state.encounter then error("AddAuraSound during an encounter") end
            state.auraSoundCount = (state.auraSoundCount or 0) + 1
            state.auraSounds = state.auraSounds or {}
            state.auraSounds[state.auraSoundCount] = {trigger = trigger, info = info}
            return state.auraSoundCount
        end,
        RemoveAuraSound = function(id)
            if state.encounter then error("RemoveAuraSound during an encounter") end
            state.auraSounds[id] = nil
        end,
        -- In client these may answer in combat: nothing for a secret aura.
        GetAuraDataBySpellName = function(unit, name, filter)
            if filter == "HELPFUL" then
                if state.combat then error("Auras cannot be accessed when secret while tainted") end
                if unit ~= "player" then
                    return ((state.units[unit] or {}).buffs or {})[name]
                end
                return (state.buffs or {})[name]
            end
            for _, aura in ipairs(auras(unit, filter)) do
                if aura.name == name then return aura end
            end
        end,
        GetUnitAuraBySpellID = function(unit, spellID)
            for _, aura in ipairs(auras(unit, "HARMFUL|PLAYER")) do
                if aura.spellId == spellID then return aura end
            end
        end,
    }
    -- Blizzard's plate frame per nameplate unit; forbidden plates are other players' or protected.
    state.plates = {}
    env.C_NamePlate = {
        GetNamePlates = function() return state.nameplates or {} end,
        GetNamePlateForUnit = function(unit)
            if not state.units[unit] then return end
            if not state.plates[unit] then
                state.plates[unit] = env.CreateFrame("Frame", nil, nil)
                state.plates[unit].forbidden = state.units[unit].forbidden
            end
            return state.plates[unit]
        end,
    }
    env.UnitAffectingCombat = function(unit)
        return unit == "player" and (state.combat or state.affectingCombat == true)
    end
    if not options.noRestrictionAPI then
        env.Enum = env.Enum or {}
        env.Enum.AddOnRestrictionType = {Combat = 0, Encounter = 1, Chat = 5}
        env.Enum.UnitAuraSoundTrigger = {Added = 0, ApplicationsIncreased = 1, Removed = 2}
        env.C_RestrictedActions = {GetAddOnRestrictionState = function(kind)
            return (state.restrictions or {})[kind] or 0
        end}
        env.C_CombatLog = {IsCombatLogRestricted = function() return state.combatLogRestricted == true end}
        env.C_RestrictedActions.IsAddOnRestrictionActive = function(kind)
            return (kind == 1 and state.encounter == true) or ((state.restrictions or {})[kind] or 0) == 2
        end
    end

    -- Settings: proxy settings with getters and setters, as the client builds them.
    if not options.noSettings then
        local function newCategory(name, parent)
            local category = {name = name, parent = parent, initializers = {}}
            function category:GetID() return "id:" .. name end
            state.categories[name] = category
            return category
        end
        local function initializer(category, setting, extra)
            local object = {setting = setting, options = extra}
            function object:SetParentInitializer(parent, predicate)
                self.parentInitializer, self.predicate = parent, predicate
            end
            object.modifyPredicates = {}
            function object:InitFrame(frame) frame.initializedWith = self end
            function object:AddModifyPredicate(predicate)
                self.modifyPredicates[#self.modifyPredicates + 1] = predicate
            end
            category.initializers[#category.initializers + 1] = object
            return object
        end
        env.MinimalSliderWithSteppersMixin = {Label = {Right = "right"}}
        env.Settings = {
            VarType = {Boolean = "boolean", Number = "number", String = "string"},
            RegisterVerticalLayoutCategory = function(name) return newCategory(name) end,
            -- Returns the page and its layout, as the client does; a heading the
            -- layout gets is kept on the page.
            RegisterVerticalLayoutSubcategory = function(parent, name)
                local page = newCategory(name, parent)
                page.headings = {}
                local layout = {}
                function layout:AddInitializer(heading) page.headings[#page.headings + 1] = heading end
                return page, layout
            end,
            -- A template row (the Toolkit's primer box): kept with its data.
            CreateElementInitializer = function(template, data)
                return {template = template, data = data}
            end,
            RegisterCanvasLayoutSubcategory = function(parent, frame, name)
                local page = newCategory(name, parent)
                page.frame = frame
                return page
            end,
            RegisterProxySetting = function(category, variable, variableType, name, default, getValue, setValue)
                equal(state.settings[variable], nil, "setting variables are unique")
                local setting = {category = category, variable = variable, type = variableType, name = name,
                    default = default}
                function setting:GetValue() return getValue() end
                function setting:SetValue(value) setValue(value) end
                state.settings[variable] = setting
                return setting
            end,
            RegisterAddOnCategory = function(category) state.registered = category end,
            CreateCheckbox = function(category, setting, tooltip)
                local object = initializer(category, setting)
                object.tooltip = tooltip
                return object
            end,
            CreateSlider = function(category, setting, sliderOptions, tooltip)
                local object = initializer(category, setting, sliderOptions)
                object.tooltip = tooltip
                return object
            end,
            CreateControlTextContainer = function()
                local container = {data = {}}
                function container:Add(value, label) self.data[#self.data + 1] = {value = value, label = label} end
                function container:GetData() return self.data end
                return container
            end,
            CreateDropdown = function(category, setting, choices, tooltip)
                local object = initializer(category, setting)
                object.tooltip, object.choices = tooltip, choices
                return object
            end,
            CreateColorSwatch = function(category, setting, tooltip)
                local object = initializer(category, setting)
                object.tooltip, object.swatch = tooltip, true
                return object
            end,
            CreateSliderOptions = function(minValue, maxValue, step)
                local object = {minValue = minValue, maxValue = maxValue, step = step}
                function object:SetLabelFormatter(label) self.label = label end
                return object
            end,
            OpenToCategory = function(id) state.opened = id end,
            InitDropdown = function(dropdown, setting, inserter)
                dropdown.setting, dropdown.inserter = setting, inserter
            end,
            NotifyUpdate = function(variable) state.notified[#state.notified + 1] = variable end,
        }
    end

    state.worldHooks = {}
    env.UIParent = {}
    env.WorldFrame = {HookScript = function(_, script, callback) state.worldHooks[script] = callback end}
    local function widget(kind, name, parent, template)
        local object = {kind = kind, name = name, parent = parent, template = template, events = {},
            unitEvents = {}, scripts = {}, attributes = {}, points = {}, shown = true, text = "", children = {}}
        if parent and parent.children then parent.children[#parent.children + 1] = object end
        function object:SetBackdropBorderColor(...) self.backdropBorder = {...} end
        function object:SetBackdrop(backdrop) self.backdrop = backdrop end
        function object:SetStatusBarColor(...) self.barColor = {...} end
        function object:SetMinMaxValues(minValue, maxValue) self.minValue, self.maxValue = minValue, maxValue end
        function object:SetStatusBarTexture(texture) self.statusBarTexture = texture end
        function object:SetValue(value) self.value = value end
        function object:GetStatusBarTexture()
            self.fill = self.fill or widget("Texture", nil, self)
            return self.fill
        end
        function object:SetClipsChildren(value) self.clips = value end
        function object:SetDesaturated(value) self.desaturated = value == true end
        function object:EnableMouse(value)
            if state.combat and self.protected then error("EnableMouse in combat") end
            self.mouse = value == true
        end
        function object:SetAlpha(value) self.alpha = value end
        -- As in client, secure frames refuse layout changes in combat.
        function object:SetScale(value)
            if state.combat and self.protected then error("SetScale in combat") end
            self.scale = value
        end
        function object:GetEffectiveScale()
            local parentScale = 1
            if self.parent and self.parent.GetEffectiveScale then parentScale = self.parent:GetEffectiveScale() end
            return (self.scale or 1) * parentScale
        end
        function object:GetWidth() return self.width or 0 end
        function object:GetHeight() return self.height or 0 end
        function object:SetWidth(width) self.width = width end
        -- As in client, in the frame's own units.
        function object:GetCenter()
            local x, y = state.absCenter(self)
            local scale = self:GetEffectiveScale()
            return x / scale, y / scale
        end
        function object:GetAlpha() return self.alpha or 1 end
        function object:SetColorTexture(...) self.color = {...} end
        function object:SetHeight(height) self.height = height end
        function object:SetSize(width, height)
            if state.combat and self.protected then error("SetSize in combat") end
            self.width, self.height = width, height
        end
        -- Fonts: a template's own size is 10; SetFont sets the size. As the
        -- worst case of the client (1.1.0: the Polymorph label grew with each
        -- slider step), SetFontObject does not reset a size SetFont set.
        function object:SetFontObject(template) self.fontTemplate = template end
        function object:GetFont() return "Fonts\\FRIZQT__.TTF", self.fontSize or 10, "" end
        function object:SetFont(_, size) self.fontSize = size end
        function object:SetIgnoreParentAlpha(value) self.ignoreParentAlpha = value end
        function object:GetNumPoints() return #self.points end
        function object:GetScale() return self.scale or 1 end
        function object:SetFrameLevel(level) self.level = level end
        function object:SetParent(newParent) self.parent = newParent end
        function object:IsForbidden() return self.forbidden == true end
        function object:CreateMaskTexture() return widget("MaskTexture", nil, self) end
        function object:GetFrameLevel() return self.level or 1 end
        function object:SetShown(value)
            if value then self:Show() else self:Hide() end
        end
        function object:SetPropagateKeyboardInput(value)
            if not options.noPropagate then self.propagate = value end
        end
        function object:GetPropagateKeyboardInput() return self.propagate == true end
        function object:EnableKeyboard(value) self.keyboard = value end
        function object:RegisterEvent(event)
            if options.restrictCombatLog and event == "COMBAT_LOG_EVENT_UNFILTERED" then
                error("COMBAT_LOG_EVENT_UNFILTERED is restricted")
            end
            self.events[event] = true
            return true
        end
        function object:RegisterUnitEvent(event, unit) self.unitEvents[event] = unit end
        function object:UnregisterEvent(event) self.events[event] = nil end
        function object:SetScript(script, callback) self.scripts[script] = callback end
        function object:HookScript(script, callback)
            local original = self.scripts[script]
            self.scripts[script] = function(...)
                if original then original(...) end
                callback(...)
            end
        end
        function object:GetScript(script) return self.scripts[script] end
        function object:GetName() return self.name end
        -- As in client, secure frames refuse changes in combat.
        function object:SetAttribute(key, value)
            if state.combat then error("SetAttribute in combat") end
            self.attributes[key] = value
        end
        function object:GetAttribute(key) return self.attributes[key] end
        function object:Show()
            if state.combat and self.protected then error("Show in combat") end
            self.shown = true
        end
        function object:Hide()
            if state.combat and self.protected then error("Hide in combat") end
            self.shown = false
        end
        function object:IsShown() return self.shown end
        function object:IsProtected() return self.protected == true end
        function object:SetPoint(...)
            if state.combat and self.protected then error("SetPoint in combat") end
            self.points[#self.points + 1] = {...}
        end
        function object:ClearAllPoints()
            if state.combat and self.protected then error("ClearAllPoints in combat") end
            self.points = {}
        end
        function object:GetPoint()
            -- As in client, a frame with no points returns nothing.
            local point = self.points[#self.points]
            if not point then return end
            return point[1], point[2], point[3], point[4], point[5]
        end
        function object:StartMoving() self.moving = true end
        function object:StopMovingOrSizing() self.moving = false end
        function object:SetText(text) self.text = text end
        function object:SetTextColor(...) self.textColor = {...} end
        function object:GetText() return self.text end
        function object:SetTexture(texture) self.texture = texture end
        function object:SetChecked(value) self.checked = value == true end
        function object:GetChecked() return self.checked end
        function object:CreateTexture() return widget("Texture", nil, self) end
        function object:CreateAnimationGroup()
            local group = {playing = false}
            function group:SetLooping(looping) self.looping = looping end
            function group:CreateAnimation(kind)
                return setmetatable({kind = kind}, {__index = function() return function() end end})
            end
            function group:Play() self.playing = true end
            function group:Stop() self.playing = false end
            function group:IsPlaying() return self.playing end
            self.animation = group
            return group
        end
        function object:EnableMouseWheel(value) self.wheel = value == true end
        function object:AddAuraSlot(key, filter, slotOptions)
            self.slots = self.slots or {}
            local button = widget("Button", nil, self)
            button.display = {}
            function button:SetIcon(region) self.display.icon = region end
            function button:SetDurationCooldown(region) self.display.cooldown = region end
            function button:SetDurationBar(region, barOptions) self.display.bar, self.display.barOptions = region, barOptions end
            function button:SetDurationText(region) self.display.text = region end
            function button:SetSpellName(region) self.display.spellName = region end
            function button:SetMouseClickEnabled(value) self.clicks = value end
            slotOptions.initializeFrame(button)
            -- As in client (WTF, 1.1.0): once handed to the engine, the slot's
            -- button and the regions given to it are the engine's; any later
            -- change from AddOn code is a forbidden access. Reads still work.
            local function forbid(region)
                if type(region) ~= "table" then return end
                region.handed = true
                local function refuse() error("Attempt to access forbidden object from code tainted by an AddOn") end
                for key, value in pairs(region) do
                    if type(value) == "function" and type(key) == "string" and not key:match("^Get")
                            and not key:match("^Is") then
                        region[key] = refuse
                    end
                end
                setmetatable(region, {__index = function(_, key)
                    if type(key) == "string" and key:match("^%u") then
                        if key:match("^Get") or key:match("^Is") then return function() end end
                        return refuse
                    end
                end})
            end
            forbid(button)
            for _, region in pairs(button.display) do forbid(region) end
            self.slots[#self.slots + 1] = {key = key, filter = filter, button = button,
                ids = slotOptions.candidateFilters.includeSpellIDs, candidates = slotOptions.candidateFilters}
            return button
        end
        function object:SetAuraSlotCandidateFilters(key, filters)
            for _, slot in ipairs(self.slots) do
                if slot.key == key then slot.ids, slot.candidates = filters.includeSpellIDs, filters end
            end
        end
        function object:SetUnit(unit) self.unit = unit end
        function object:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
        function object:CreateFontString() return widget("FontString", nil, self) end
        -- Unknown methods (layout, colors, and so on) do nothing here.
        return setmetatable(object, {__index = function(_, key)
            if type(key) == "string" and key:match("^%u") then return function() end end
        end})
    end
    env.CreateFrame = function(kind, name, parent, template)
        local frame = widget(kind, name, parent, template)
        if name then env[name] = frame end
        if kind == "AuraContainer" then
            equal(template, "CustomAuraContainerTemplate")
            equal(state.loadedAddOns and state.loadedAddOns.Blizzard_AuraContainer, true, "container AddOn loaded")
        end
        if template == "SecureActionButtonTemplate" then
            frame.protected = true
            if parent then parent.protected = true end
        end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    -- UIParent is a frame like any other here, so text can be drawn on it.
    env.UIParent = widget("Frame", "UIParent")
    env.UIParent.width, env.UIParent.height = 1000, 800
    env.IsShiftKeyDown = function() return state.shift == true end
    env.IsControlKeyDown = function() return state.ctrl == true end
    env.IsAltKeyDown = function() return state.alt == true end
    local SPOTS = {CENTER = {0.5, 0.5}, BOTTOMLEFT = {0, 0}, TOP = {0.5, 1}, TOPLEFT = {0, 1}, LEFT = {0, 0.5}}
    -- Screen position of a frame's center, from its last point.
    function state.absCenter(frame)
        if frame == env.UIParent or frame == nil then return 500, 400 end
        local point = frame.points[#frame.points]
        local relative = point[2] or env.UIParent
        local relativeScale = relative == env.UIParent and 1 or relative:GetEffectiveScale()
        local rx, ry = state.absCenter(relative)
        local spot = SPOTS[point[3]]
        local width = (relative.width or 0) * relativeScale
        local height = (relative.height or 0) * relativeScale
        local scale = frame:GetEffectiveScale()
        return rx + (spot[1] - 0.5) * width + (point[4] or 0) * scale,
            ry + (spot[2] - 0.5) * height + (point[5] or 0) * scale
    end
    function state.emit(event, ...)
        -- The game re-reads state drivers as units change, before AddOns hear of it.
        state.applyDrivers()
        for _, frame in ipairs(state.frames) do
            local unit = frame.unitEvents[event]
            local first = ...
            if frame.events[event] or (unit and unit == first) then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end

    for _, name in ipairs(options.remove or {}) do env[name] = nil end
    -- options.noFocus: Classic Era, whose client keeps no focus unit (John's
    -- probe: after /focus, UnitExists("focus") is false).
    if options.noFocus then
        local unitExists = env.UnitExists
        env.UnitExists = function(unit)
            if unit == "focus" then return false end
            return unitExists(unit)
        end
        local unitGUID = env.UnitGUID
        env.UnitGUID = function(unit)
            if unit == "focus" then return nil end
            return unitGUID(unit)
        end
    end
    -- Dyre's Toolkit, its real files (TOOLKIT_DIR): MTF requires it. Not the
    -- minimap, which needs the embedded libraries. options.noToolkit leaves it
    -- out; options.oldToolkit offers contract 1 only; options.noProfiles is a
    -- Toolkit older than 2.10.0 (no RegisterProfilePart).
    env.GetRealmName = function() return options.realm or "Forever" end
    if not options.noToolkit then
        state.toolkitNS = {InitializeMinimap = function() end}
        for _, path in ipairs(TOOLKIT_FILES) do
            local chunk = assert(loadfile(TOOLKIT_DIR .. path))
            setfenv(chunk, env)
            chunk("DyresToolkit", state.toolkitNS)
        end
        state.toolkit = env.DyresToolkit
        if options.noProfiles then
            env.DyresToolkit.RegisterProfilePart = nil
        end
        -- options.noBarLayout: a Toolkit older than 2.18.0 (no button bar layout).
        if options.noBarLayout then
            env.DyresToolkit.BAR_LAYOUT_VERSION = nil
        end
        -- options.sections: "none" is a Toolkit older than 2.17.0 (no
        -- AddSettingsSection); "rows" or "link" is a mock that records each
        -- call in state.sectionCalls and gives that outcome ("link" draws the
        -- link row, as the Toolkit's fallback does). A "master" call (only the
        -- section's top switch) goes in state.masterCalls, the others in
        -- state.pageCalls; with "link", a master gives nil and draws nothing,
        -- as the Toolkit does. options.sectionsVersion sets
        -- SETTINGS_SECTIONS_VERSION (2 by default: no master and rest parts).
        if options.sections == "none" then
            env.DyresToolkit.AddSettingsSection = nil
        elseif options.sections then
            state.sectionCalls, state.masterCalls, state.pageCalls = {}, {}, {}
            local outcome, toolkit = options.sections, env.DyresToolkit
            toolkit.SETTINGS_SECTIONS_VERSION = options.sectionsVersion or 2
            -- options.sectionTitles: {addon = {key = title}}, the owners' names.
            toolkit.SettingsSectionTitle = function(addon, key)
                return options.sectionTitles and options.sectionTitles[addon] and options.sectionTitles[addon][key]
            end
            -- The primer box (2.17.0); options.noPrimer is a build without it.
            if options.noPrimer then
                toolkit.AddSettingsPrimer = nil
            elseif type(toolkit.AddSettingsPrimer) ~= "function" then
                toolkit.AddSettingsPrimer = function() return true end
            end
            toolkit.AddSettingsSection = function(category, layout, opts)
                local call = {category = category, layout = layout, opts = opts}
                state.sectionCalls[#state.sectionCalls + 1] = call
                if opts.part == "master" then
                    state.masterCalls[#state.masterCalls + 1] = call
                    return outcome == "rows" and "rows" or nil
                end
                state.pageCalls[#state.pageCalls + 1] = call
                if outcome == "link" then
                    toolkit.AddSettingsLink(category, layout, opts.link)
                end
                return outcome
            end
        end
        -- options.welcome: "none" is a Toolkit older than 2.14.0 (no
        -- ShowWelcome); true or false is what ShowWelcome returns.
        if options.welcome == "none" then
            env.DyresToolkit.ShowWelcome = nil
        elseif options.welcome ~= nil then
            local shown = options.welcome
            env.DyresToolkit.ShowWelcome = function() return shown end
        end
        if options.oldToolkit then
            local require = env.DyresToolkit.RequireContract
            env.DyresToolkit.RequireContract = function(n)
                if n >= 2 then return nil end
                return require(n)
            end
        end
        -- Toolkit 2.2.1 snaps to the grid by default; these tests drop frames without it.
        env.DyresToolkitDB = options.toolkitDB or {snapToGrid = false}
    end
    state.mtf = {}
    for _, path in ipairs(options.files or RUNTIME_FILES) do
        local chunk, message = loadfile(path)
        if not chunk then error(message) end
        setfenv(chunk, env)
        chunk("MageToolsForever", state.mtf)
    end
    env.MageToolsForeverDB = options.db
    -- Per client: a Forever client has seen a focus; a Classic one starts
    -- fresh. options.accountDB sets it (false: fresh).
    local accountDB = options.accountDB
    if accountDB == nil then
        accountDB = not options.classic and {focusWorks = true} or false
    end
    env.MageToolsForeverAccountDB = accountDB or nil
    state.env = env
    state.emit("ADDON_LOADED", "DyresToolkit")
    state.openedCompanion = {}
    for _, addon in ipairs(options.companions or {}) do
        state.loadedAddOns = state.loadedAddOns or {}
        state.loadedAddOns[addon] = true
        env.DyresToolkit.RegisterAddOn({addon = addon, title = addon,
            openSettings = function() state.openedCompanion[#state.openedCompanion + 1] = addon end})
    end
    state.emit("ADDON_LOADED", "MageToolsForever")
    state.emit("PLAYER_LOGIN")

    -- Slash commands, key presses, and world clicks are hardware events.
    local function hardware(action)
        state.hardware = true
        action()
        state.hardware = false
    end
    function state.slash(text) hardware(function() env.SlashCmdList.MAGETOOLSFOREVER(text) end) end
    function state.press()
        hardware(function()
            for _, frame in ipairs(state.frames) do
                if frame.keyboard and frame.scripts.OnKeyDown then frame.scripts.OnKeyDown(frame, "1") end
            end
        end)
    end
    -- modifiers: nil, or the client's prefix order, such as "shift" or
    -- "ctrl-shift". As SecureTemplates.lua: the attribute with exactly that
    -- prefix, else the plain one; "" (ATTRIBUTE_NOOP) means no action.
    function state.clickButton(name, mouseButton, modifiers)
        local button = env[name]
        local suffix = mouseButton == "RightButton" and "2" or mouseButton == "MiddleButton" and "3" or "1"
        local prefix = modifiers and (modifiers .. "-") or ""
        local function attribute(key)
            local value = button.attributes[prefix .. key .. suffix]
            if value == nil then
                value = button.attributes[key .. suffix]
            end
            if value == "" then
                value = nil
            end
            return value
        end
        state.shift = prefix:find("shift%-") ~= nil
        state.ctrl = prefix:find("ctrl%-") ~= nil
        state.alt = prefix:find("alt%-") ~= nil
        hardware(function()
            local actionType = attribute("type")
            state.used = {type = actionType, item = actionType and attribute("item"),
                macrotext = actionType and attribute("macrotext"), spell = actionType and attribute("spell")}
            -- Secure buttons run PostClick for the press and the release.
            button.scripts.PostClick(button, mouseButton, true)
            button.scripts.PostClick(button, mouseButton, false)
        end)
        state.shift, state.ctrl, state.alt = false, false, false
    end
    function state.click()
        hardware(function() state.worldHooks.OnMouseDown(env.WorldFrame, "RightButton") end)
    end
    -- A stack of an item in a bag slot; settled bags then report it.
    function state.put(bag, slot, itemID, count)
        state.bags[bag].items[slot] = {itemID = itemID, stackCount = count or 1}
    end
    function state.cast(spellID)
        state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. spellID, spellID)
    end
    function state.last() return state.messages[#state.messages] end
    function state.clear() state.messages = {} end
    return state
end

-- Commands ----------------------------------------------------------------------

test("texture and sound paths escape their backslashes", function()
    -- A path written "Interface\Icons\X" loses its backslashes in Lua.
    for _, path in ipairs(RUNTIME_FILES) do
        local source = assert(io.open(path)):read("*a")
        for before, after in source:gmatch('"(%a+)\\(.)') do
            if (before == "Interface" or before == "Sound") and after ~= "\\" then
                error(path .. ": unescaped path starting " .. before)
            end
        end
    end
end)
test("commands are one word; extra words and unknown commands show usage", function()
    local state = fixture()
    local parse = state.mtf.ParseCommand
    equal(parse(""), "")
    equal(parse("  OPTIONS "), "options")
    equal(parse("conjure"), "conjure")
    equal(parse("debug_portals"), "debug_portals")
    equal(parse("debug_shield"), nil, "the shield moved to Dyre's Shields Up")
    equal(parse("debug_chimes"), nil)
    equal(parse("debug_reminders"), nil)
    local command, usage = parse("conjure 10")
    equal(command, nil)
    contains(usage, "/mtf debug_conjure")
    equal(parse("dance"), nil)
    equal(parse(nil), nil)
end)
test("/mtf and /mtf options open the settings page", function()
    local state = fixture()
    state.slash("")
    equal(state.opened, "id:Mage Tools Forever")
    state.opened = nil
    state.slash("options")
    equal(state.opened, "id:Mage Tools Forever")
end)
test("/magetools is a backup slash command", function()
    local state = fixture()
    equal(state.env.SLASH_MAGETOOLSFOREVER1, "/mtf")
    equal(state.env.SLASH_MAGETOOLSFOREVER2, "/magetools")
end)
test("another AddOn registering /mtf is reported once at login", function()
    local state = fixture({slashCmdList = {OTHERADDON = function() end},
        globals = {SLASH_OTHERADDON1 = "/other", SLASH_OTHERADDON2 = "/MTF"}})
    local found = 0
    for _, message in ipairs(state.messages) do
        if message:find("Another AddOn (OTHERADDON) also uses /mtf. Use /magetools instead.", 1, true) then
            found = found + 1
        end
    end
    equal(found, 1)
end)

-- Login and availability --------------------------------------------------------

test("login prints the banner from the TOC and the ready hint", function()
    local state = fixture()
    equal(state.messages[1], "MTF: Mage Tools Forever " .. state.toc.Version .. " by Dyre")
    contains(state.messages[2], "Type /mtf to open the settings.")
    equal(state.mtf.available, true)
end)
test("other classes get one message and commands are refused", function()
    local state = fixture({class = "WARLOCK"})
    equal(state.mtf.available, false)
    contains(state.last(), "is for Mages")
    state.clear()
    state.slash("conjure")
    contains(state.last(), "Mage Tools Forever is unavailable")
    equal(state.categories["Mage Tools Forever"], nil, "no settings page")
end)
test("diagnostics still run when MTF is unavailable", function()
    local state = fixture({class = "WARLOCK"})
    state.clear()
    state.slash("debug_conjure")
    contains(state.messages[1], "debug_conjure water spell=5504 name=Conjure Water(Rank 1)")
end)
test("a missing client API disables MTF with one message naming it", function()
    local state = fixture({remove = {"InitiateTrade"}})
    equal(state.mtf.available, false)
    contains(state.last(), "it lacks InitiateTrade")
    equal(state.categories["Mage Tools Forever"], nil, "no settings page")
end)
test("a mixed install of old and new files is reported at login", function()
    local state = fixture({files = {"Commands.lua", "Core.lua", "Conjure.lua", "Options.lua"}})
    equal(state.mtf.available, false)
    contains(state.last(), "Reinstall every Mage Tools Forever file")
end)

-- Saved settings ---------------------------------------------------------------

test("saved settings get defaults and are repaired on load", function()
    local state = fixture()
    local db = state.mtf.db
    equal(db.conjure.enabled, true)
    equal(db.locked, true, "every frame locked by default")
    equal(db.conjure.macros, true)
    equal(db.conjure.shareSize, 10)
    equal(db.shield, nil, "no shield settings of MTF's own")
    equal(db.chimes, nil)
    equal(db.reminders, nil)
    local repaired = fixture({db = {conjure = {shareSize = 99, position = {point = 1}}}})
    db = repaired.mtf.db
    equal(db.conjure.shareSize, 20)
    equal(db.conjure.position, nil)
    equal(fixture({db = {conjure = {shareSize = "lots"}}}).mtf.db.conjure.shareSize, 10)
end)

-- Conjure: water and food ---------------------------------------------------------

local WATER_BUTTON, FOOD_BUTTON, GEM_BUTTON = "MageToolsForeverWater", "MageToolsForeverFood", "MageToolsForeverManaGem"
local BOTH_BUTTON = "MageToolsForeverFoodAndWater"
-- A level 25 Mage with three ranks of water and food.
local function mage(extra)
    local options = {known = {[5504] = true, [5505] = true, [5506] = true, [587] = true, [597] = true, [990] = true},
        units = {player = {name = "Dyre", player = true, friend = true, level = 25}}}
    for key, value in pairs(extra or {}) do
        if key == "known" then
            for id, known in pairs(value) do options.known[id] = known end
        elseif key == "units" then
            for unit, data in pairs(value) do options.units[unit] = data end
        else
            options[key] = value
        end
    end
    return fixture(options)
end
local function friend(level)
    return {target = {name = "Lowbie", surname = "Smith", player = true, friend = true, level = level}}
end
local function macroBody(state, name)
    for _, macro in ipairs(state.macros) do
        if macro.name == name then return macro.body end
    end
end

test("with no one targeted, left-click drinks your best and right-click conjures your best", function()
    local state = mage()
    state.put(0, 1, WATER_FRESH, 5)
    state.put(0, 2, WATER_PURIFIED, 8)
    state.emit("BAG_UPDATE_DELAYED")
    local water = state.env[WATER_BUTTON]
    equal(water.mode, "use")
    equal(water.attributes.type1, "item")
    equal(water.attributes.item1, "item:" .. WATER_PURIFIED)
    equal(water.attributes.type2, "spell")
    equal(water.attributes.spell2, 5506)
    equal(water.attributes.item3, "item:" .. WATER_PURIFIED, "middle-click is always you")
    equal(water.count.text, 8)
    local food = state.env[FOOD_BUTTON]
    equal(food.attributes.spell2, 990)
    equal(food.attributes.type1, nil, "no food carried")
    state.clear()
    state.clickButton(FOOD_BUTTON, "LeftButton")
    equal(state.last(), "MTF: No conjured food in your bags. Right-click to conjure some.")
end)
test("without the client's item data, each rank's Classic level stands in", function()
    -- In client, ranks not carried had no item data, so no level.
    local state = mage({units = friend(8)})
    state.env.C_Item.GetItemInfo = function(id)
        if id == WATER_PURIFIED then return "Conjured Purified Water", "link", 1, 10, 15 end
    end
    state.emit("PLAYER_TARGET_CHANGED")
    equal(state.env[WATER_BUTTON].attributes.spell2, 5505, "Fresh Water (level 5) for a level 8 player")
end)
test("with a friend targeted, right-click conjures the best rank they can use", function()
    local state = mage({units = friend(10)})
    local water = state.env[WATER_BUTTON]
    equal(water.mode, "trade")
    equal(water.attributes.spell2, 5505, "Fresh Water needs level 5; Purified needs 15")
    equal(water.attributes.type1, nil, "left-click trades instead")
    local food = state.env[FOOD_BUTTON]
    equal(food.attributes.spell2, 597)
end)
test("left-click trades exactly the share stack size, splitting a bigger stack", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.tradeWith, "target")
    equal(state.bags[0].items[1].stackCount, 10, "split at the click")
    equal(state.bags[0].items[2].stackCount, 10, "into an empty slot")
    state.clear()
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 10, "not the whole stack the split came from")
    equal(state.bags[0].items[1].stackCount, 10, "the rest stays for the next party member")
    equal(state.cursor, nil)
    equal(state.last(), "MTF: 10 Conjured Fresh Water in the trade window. Press Trade to give it.")
end)
test("with full bags, a small stack is topped up from a big one, needing no free slot", function()
    local bags = {[0] = {size = 2, family = 0, items = {}}, [1] = {size = 0, family = 0, items = {}},
        [2] = {size = 0, family = 0, items = {}}, [3] = {size = 0, family = 0, items = {}},
        [4] = {size = 0, family = 0, items = {}}}
    local state = mage({units = friend(10), bags = bags})
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, WATER_FRESH, 3)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.bags[0].items[2].stackCount, 10, "the 3 topped up")
    equal(state.bags[0].items[1].stackCount, 13)
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 10)
    equal(state.tradeSlots[1].count, 10, "one stack")
end)
test("smaller stacks are merged into one stack of exactly the share size", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 6)
    state.put(0, 2, WATER_FRESH, 8)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.bags[0].items[2].stackCount, 10, "the 8 topped up from the 6")
    equal(state.bags[0].items[1].stackCount, 4)
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 10)
    equal(state.tradeSlots[1].count, 10, "a single stack")
    equal(state.tradeSlots[2], nil)
end)
test("an exact stack is used as it is, and a bigger one is split, keeping big stacks whole", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, WATER_FRESH, 10)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(state.tradeSlots[1].count, 10)
    equal(state.bags[0].items[1].stackCount, 20, "untouched")
    state.emit("TRADE_CLOSED")
    local other = mage({units = friend(10)})
    other.put(0, 1, WATER_FRESH, 20)
    other.put(0, 2, WATER_FRESH, 14)
    other.emit("BAG_UPDATE_DELAYED")
    other.clickButton(WATER_BUTTON, "LeftButton")
    equal(other.bags[0].items[2].stackCount, 4, "split from the 14, the smaller big stack")
    equal(other.bags[0].items[1].stackCount, 20)
end)
test("with less than the share size, they get all of it", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 4)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 4)
end)
test("the share stack size setting changes the trade", function()
    local state = mage({units = friend(10)})
    state.settings.MTF_CONJURE_SHARE_SIZE:SetValue(3)
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 3)
    state.settings.MTF_CONJURE_SHARE_SIZE:SetValue(50)
    equal(state.mtf.db.conjure.shareSize, 20, "at most 20")
end)
test("the share stack size slider has the Toolkit's gold mark at its default", function()
    -- John: "set notches on the sliders default values".
    local state = mage()
    local mark
    for _, initializer in ipairs(state.categories.Conjure.initializers) do
        if initializer.setting and initializer.setting.variable == "MTF_CONJURE_SHARE_SIZE" then
            mark = initializer.dyreDefault
        end
    end
    equal(type(mark), "table", "a mark")
    equal(mark.min, state.mtf.SHARE_SIZE_MIN)
    equal(mark.max, state.mtf.SHARE_SIZE_MAX)
    equal(mark.default, state.mtf.DEFAULT_SHARE_SIZE)
    equal(mark.default, 10)
end)
test("the best a friend can use is traded, and with none MTF says to conjure first", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_PURIFIED, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clear()
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.tradeWith, nil, "no trade")
    equal(state.last(), "MTF: You have no conjured water a level 10 player can use. Right-click to conjure some first.")
    state.put(0, 2, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 10)
    equal(state.traded(WATER_PURIFIED), 0)
end)
test("middle-click always drinks your own best, whoever you target", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, WATER_PURIFIED, 20)
    state.emit("BAG_UPDATE_DELAYED")
    local water = state.env[WATER_BUTTON]
    equal(water.attributes.item3, "item:" .. WATER_PURIFIED)
    state.clickButton(WATER_BUTTON, "MiddleButton")
    equal(state.used.item, "item:" .. WATER_PURIFIED)
    equal(state.tradeWith, nil)
end)
test("a split share needs an empty bag slot; with full bags nothing is traded", function()
    local bags = {[0] = {size = 1, family = 0, items = {}}, [1] = {size = 0, family = 0, items = {}},
        [2] = {size = 0, family = 0, items = {}}, [3] = {size = 0, family = 0, items = {}},
        [4] = {size = 0, family = 0, items = {}}}
    local state = mage({units = friend(10), bags = bags})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clear()
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.tradeWith, nil)
    equal(state.last(), "MTF: Sorry, your bags are full! Free one bag slot so MTF can split 10 off your 20 "
        .. "Conjured Fresh Water, then try again.")
    contains(state.errors[1], "your bags are full", "also in red at the top of the screen")
    equal(state.bags[0].items[1].stackCount, 20, "untouched")
end)
test("the player is whispered as the trade window opens, and the switch turns it off", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(#state.sent, 0, "not before the window opens")
    state.emit("TRADE_SHOW")
    equal(#state.sent, 1)
    equal(state.sent[1].chatType, "WHISPER")
    equal(state.sent[1].target, "Lowbie-Smith")
    equal(state.sent[1].message, "Here's 10 Conjured Fresh Water. Enjoy, Lowbie Smith!")
    state.emit("TRADE_CLOSED")
    state.mtf.announcePage:OnRefresh()
    local waterRow = state.mtf.announcePage.rows[1]
    equal(waterRow.switch, "waterWhisper")
    waterRow.check:SetChecked(false)
    waterRow.check.scripts.OnClick(waterRow.check)
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(#state.sent, 1)
end)
test("a freshly split stack still locked is placed as soon as the server unlocks it", function()
    local state = mage({units = friend(10)})
    state.lockMoves = true
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.bags[0].items[2].isLocked, true, "the split waits for the server")
    state.clear()
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 0, "locked: waits")
    equal(#state.messages, 0, "no give-up message yet")
    state.bags[0].items[2].isLocked = false
    state.emit("ITEM_LOCK_CHANGED", 0, 2)
    equal(state.traded(WATER_FRESH), 10, "placed on unlock, with no click")
    equal(state.last(), "MTF: 10 Conjured Fresh Water in the trade window. Press Trade to give it.")
end)
test("a split slot that still shows empty is waited for, then placed", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    -- The client has not filled the new slot yet.
    local split = state.bags[0].items[2]
    state.bags[0].items[2] = nil
    state.clear()
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 0)
    equal(#state.messages, 0, "waits, no give-up message")
    state.bags[0].items[2] = split
    state.emit("BAG_UPDATE_DELAYED")
    equal(state.traded(WATER_FRESH), 10, "placed once it shows")
    state.clear()
    state.slash("debug_conjure")
    contains(table.concat(state.messages, "|"), "waiting bag 0 slot 2 empty")
end)
test("a split that never unlocks gives up after a few seconds, once", function()
    local state = mage({units = friend(10)})
    state.lockMoves = true
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    state.clear()
    state.now = state.now + 6
    state.runTimers()
    equal(state.last(), "MTF: MTF could not put the Conjured Fresh Water into the trade window; drag it in yourself.")
    state.emit("ITEM_LOCK_CHANGED", 0, 2)
    equal(#state.messages, 1, "once")
end)
test("when someone opens a trade with you, the buttons serve them, straight into the window", function()
    local state = mage()
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, WATER_PURIFIED, 20)
    state.emit("BAG_UPDATE_DELAYED")
    local water = state.env[WATER_BUTTON]
    equal(water.mode, "use", "no target: drinks")
    -- Another player opens a trade; you target no one.
    state.units.NPC = {name = "Runner", surname = "Uppe", player = true, friend = true, level = 10}
    state.emit("TRADE_SHOW")
    equal(water.mode, "trade", "the trade partner, by their level")
    equal(water.attributes.spell2, 5505, "right-click conjures what they can use")
    state.clear()
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.tradeWith, nil, "no new trade")
    equal(state.traded(WATER_FRESH), 10, "into the open window")
    equal(state.traded(WATER_PURIFIED), 0, "only what they can use")
    equal(state.sent[1].target, "Runner-Uppe")
    contains(state.sent[1].message, "Enjoy, Runner Uppe!")
    state.emit("TRADE_CLOSED")
    state.units.NPC = nil
    equal(water.mode, "use", "back to following your target")
end)
test("water then food in one trade: the second click adds to the open window", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, 1113, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    -- In client the trade partner is unit NPC while the window is open.
    state.units.NPC = state.units.target
    state.emit("TRADE_SHOW")
    state.tradeWith = nil
    state.clickButton(FOOD_BUTTON, "LeftButton")
    equal(state.tradeWith, nil, "no second trade")
    equal(state.traded(WATER_FRESH), 10)
    equal(state.traded(1113), 10, "the bread joins the water")
    equal(#state.sent, 1, "one whisper per player every 30 seconds")
    state.emit("TRADE_CLOSED")
    state.now = state.now + 31
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(#state.sent, 2, "whispered again after 30 seconds")
end)
test("a trade window MTF missed opening still counts as open", function()
    local state = mage({units = friend(10), globals = {TradeFrame = {IsShown = function() return true end}}})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.tradeWith, nil, "no InitiateTrade into an open window")
    equal(state.traded(WATER_FRESH), 10)
end)
test("a refused trade placement waits for the next key press, once", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.tradeNeedsHardware = true
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 0)
    equal(state.cursor, nil, "the share is back in its bag slot")
    equal(state.bags[0].items[2].stackCount, 10)
    state.press()
    equal(state.traded(WATER_FRESH), 10, "placed on the key press")
end)
test("a trade window long after the click, or from someone else, gets nothing", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(WATER_BUTTON, "LeftButton")
    state.now = state.now + 30
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 0)
end)
test("button actions change only out of combat", function()
    local state = mage()
    state.combat = true
    state.units.target = friend(10).target
    state.emit("PLAYER_TARGET_CHANGED")
    equal(state.env[WATER_BUTTON].mode, "use", "unchanged in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.env[WATER_BUTTON].mode, "trade")
end)
test("unknown spells and unusable ranks are explained", function()
    local state = mage({known = {[587] = false, [597] = false, [990] = false}, units = friend(3)})
    state.clear()
    state.clickButton(FOOD_BUTTON, "RightButton")
    equal(state.last(), "MTF: You do not know Conjure Food yet.")
    state.units.target.level = 0
    state.units.target = {name = "Tiny", player = true, friend = true, level = 1}
    state.emit("PLAYER_TARGET_CHANGED")
    equal(state.env[WATER_BUTTON].attributes.spell2, 5504, "Conjured Water needs level 1")
end)

-- Conjure: Food & Water --------------------------------------------------------------

test("Food & Water eats and drinks your best, and conjures water and food in turn", function()
    local state = mage()
    state.put(0, 1, WATER_PURIFIED, 8)
    state.put(0, 2, FOOD_RYE, 8)
    state.emit("BAG_UPDATE_DELAYED")
    local both = state.env[BOTH_BUTTON]
    equal(both.mode, "use")
    equal(both.attributes.type1, "macro")
    equal(both.attributes.macrotext1, "/use item:" .. WATER_PURIFIED .. "\n/use item:" .. FOOD_RYE)
    equal(both.attributes.macrotext3, both.attributes.macrotext1, "middle-click is always you")
    equal(both.attributes.macrotext2, "/castsequence Conjure Water(Rank 3), Conjure Food(Rank 3)",
        "one spell per click, in turn")
    equal(both.points[1][4], 6 + 2 * 42, "third on the bar, after Water and Food")
    equal(state.env[GEM_BUTTON].points[1][4], 6 + 3 * 42)
    equal(state.env.MageToolsForeverConjure.width, 6 * 2 + 36 * 4 + 6 * 3)
end)
test("Food & Water trades both shares in one click, with one whisper", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, 1113, 20)
    state.emit("BAG_UPDATE_DELAYED")
    local both = state.env[BOTH_BUTTON]
    equal(both.mode, "trade")
    equal(both.attributes.type1, nil, "left-click trades instead")
    equal(both.attributes.macrotext2, "/castsequence Conjure Water(Rank 2), Conjure Food(Rank 2)",
        "the ranks they can use")
    state.clickButton(BOTH_BUTTON, "LeftButton")
    equal(state.tradeWith, "target")
    state.units.NPC = state.units.target
    state.clear()
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 10)
    equal(state.traded(1113), 10)
    equal(#state.sent, 1, "one whisper for both")
    equal(state.sent[1].message, "Here's 10 Conjured Fresh Water and 10 Conjured Bread. Enjoy, Lowbie Smith!")
    equal(state.last(), "MTF: 10 Conjured Fresh Water and 10 Conjured Bread in the trade window. Press Trade to give it.")
end)
test("Food & Water trades what it can, and says when it has nothing they can use", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.emit("BAG_UPDATE_DELAYED")
    state.clickButton(BOTH_BUTTON, "LeftButton")
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 10, "the water, though there is no bread")
    local none = mage({units = friend(10)})
    none.clear()
    none.clickButton(BOTH_BUTTON, "LeftButton")
    equal(none.tradeWith, nil)
    contains(none.last(), "You have no conjured food and water a level 10 player can use.")
end)
-- Shift + left-click (2026-11-17; a player report: in dungeons a healer or
-- tank target turned each drink after a pull into a trade).
test("Shift + left-click eats or drinks your own best, even with a player targeted", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, WATER_PURIFIED, 8)
    state.put(0, 3, 1113, 20)
    state.emit("BAG_UPDATE_DELAYED")
    local water = state.env[WATER_BUTTON]
    equal(water.mode, "trade")
    state.clickButton(WATER_BUTTON, "LeftButton", "shift")
    equal(state.tradeWith, nil, "no trade")
    equal(state.used.type, "item")
    equal(state.used.item, "item:" .. WATER_PURIFIED, "your own best, not the share rank")
    state.clickButton(BOTH_BUTTON, "LeftButton", "shift")
    equal(state.tradeWith, nil, "Food & Water does not trade either")
    equal(state.used.type, "macro")
    equal(state.used.macrotext, "/use item:" .. WATER_PURIFIED .. "\n/use item:1113")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.tradeWith, "target", "a plain left-click still trades")
    equal(state.used.type, nil, "and uses nothing")
    water.scripts.OnEnter(water)
    contains(state.tooltip[2], "Left-click: trade up to 10")
    equal(state.tooltip[3], "Shift-click: use Conjured Purified Water.")
end)
test("Shift + left-click with no target is a plain left-click", function()
    local state = mage()
    state.put(0, 1, WATER_PURIFIED, 8)
    state.emit("BAG_UPDATE_DELAYED")
    local water = state.env[WATER_BUTTON]
    equal(water.attributes["shift-type1"], nil, "falls back to left-click")
    state.clickButton(WATER_BUTTON, "LeftButton", "shift")
    equal(state.used.item, "item:" .. WATER_PURIFIED)
    water.scripts.OnEnter(water)
    equal(state.tooltip[2], "Left-click: use Conjured Purified Water.")
    equal(state.tooltip[3]:find("Shift"), nil, "no Shift line with the setting off")
end)
test("Trade only with Shift-click: left-click always drinks, Shift + left-click trades", function()
    local state = mage({units = friend(10), db = {conjure = {shiftTrade = true}}})
    equal(state.mtf.db.conjure.shiftTrade, true)
    state.put(0, 1, WATER_FRESH, 20)
    state.put(0, 2, WATER_PURIFIED, 8)
    state.put(0, 3, 1113, 20)
    state.emit("BAG_UPDATE_DELAYED")
    local water = state.env[WATER_BUTTON]
    equal(water.attributes["shift-type1"], "", "ATTRIBUTE_NOOP: Shift does not fall back to the drink")
    state.clickButton(WATER_BUTTON, "LeftButton")
    equal(state.tradeWith, nil, "no trade")
    equal(state.used.item, "item:" .. WATER_PURIFIED, "drinks your best")
    state.clickButton(WATER_BUTTON, "LeftButton", "ctrl-shift")
    equal(state.tradeWith, nil, "Ctrl with Shift falls back to the drink, so it does not also trade")
    state.clickButton(BOTH_BUTTON, "LeftButton")
    equal(state.tradeWith, nil)
    equal(state.used.type, "macro", "Food & Water eats and drinks")
    state.clickButton(WATER_BUTTON, "LeftButton", "shift")
    equal(state.tradeWith, "target", "Shift + left-click trades")
    equal(state.used.type, nil, "and uses nothing")
    state.emit("TRADE_SHOW")
    equal(state.traded(WATER_FRESH), 10)
    water.scripts.OnEnter(water)
    equal(state.tooltip[2], "Left-click: use Conjured Purified Water.")
    contains(state.tooltip[3], "Shift-click: trade up to 10")
    local both = state.env[BOTH_BUTTON]
    equal(both.attributes["shift-type1"], "")
    both.scripts.OnEnter(both)
    equal(state.tooltip[2], "Left-click: eat and drink your best.")
    contains(state.tooltip[3], "Shift-click: trade up to 10 each of")
end)
test("Trade only with Shift-click applies at once, waits out combat, and is in the profile", function()
    local state = mage({units = friend(10)})
    state.put(0, 1, WATER_PURIFIED, 8)
    state.emit("BAG_UPDATE_DELAYED")
    local water = state.env[WATER_BUTTON]
    equal(water.attributes.type1, nil, "off by default: left-click trades")
    state.combat = true
    state.mtf.db.conjure.shiftTrade = true
    state.mtf.RefreshConjure()
    equal(water.attributes.type1, nil, "secure actions wait for combat to end")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(water.attributes.type1, "item")
    local untargeted = mage({db = {conjure = {shiftTrade = true}}})
    untargeted.put(0, 1, WATER_PURIFIED, 8)
    untargeted.emit("BAG_UPDATE_DELAYED")
    local alone = untargeted.env[WATER_BUTTON]
    equal(alone.attributes["shift-type1"], nil, "untargeted, Shift falls back to the drink")
    alone.scripts.OnEnter(alone)
    equal(untargeted.tooltip[3], "Shift-click: trade, with a friendly player targeted.")
    equal(state.mtf.SanitizeDB({conjure = {shiftTrade = "yes"}}).conjure.shiftTrade, false, "only true counts")
end)
test("the Food & Water macro uses one item each and conjures in turn", function()
    local state = mage()
    state.put(0, 1, WATER_PURIFIED, 8)
    state.put(0, 2, FOOD_RYE, 8)
    state.emit("BAG_UPDATE_DELAYED")
    local body = macroBody(state, "! Food & Water")
    equal(body, table.concat({
        "#showtooltip item:" .. WATER_PURIFIED,
        "/castsequence [btn:2] Conjure Water(Rank 3), Conjure Food(Rank 3)",
        "/stopmacro [btn:2]",
        "/use item:" .. WATER_PURIFIED,
        "/use item:" .. FOOD_RYE}, "\n"))
    if #body > 255 then error("over the macro limit") end
end)

-- Conjure: mana gems ---------------------------------------------------------------

test("before Conjure Mana Agate, the gem button says when it comes and has no macro", function()
    local state = mage()
    local gem = state.env[GEM_BUTTON]
    equal(gem.icon.desaturated, true)
    equal(gem.attributes.type1, nil)
    equal(gem.attributes.type2, nil)
    state.clear()
    state.clickButton(GEM_BUTTON, "RightButton")
    equal(state.last(), "MTF: You learn Conjure Mana Agate at level 28.")
    state.now = state.now + 1
    state.clickButton(GEM_BUTTON, "LeftButton")
    equal(state.last(), "MTF: You learn Conjure Mana Agate at level 28.")
    equal(macroBody(state, "! Mana Gem"), nil, "no macro until the spell exists")
    gem.scripts.OnEnter(gem)
    contains(state.tooltip[2], "level 28")
end)
test("mana gems: right-click conjures one you do not carry; left-click uses your best", function()
    local state = mage({known = {[759] = true}})
    local gem = state.env[GEM_BUTTON]
    equal(gem.icon.desaturated, false)
    equal(gem.attributes.spell2, 759)
    contains(macroBody(state, "! Mana Gem"), "/use [btn:2] Conjure Mana Agate(Rank 1)")
    state.put(0, 1, 5514, 1)
    state.emit("BAG_UPDATE_DELAYED")
    equal(gem.attributes.item1, "item:5514")
    equal(gem.attributes.item3, "item:5514")
    equal(gem.attributes.type2, nil, "you carry the only rank you know")
    state.clear()
    state.clickButton(GEM_BUTTON, "RightButton")
    equal(state.last(), "MTF: You already carry every mana gem you can conjure.")
end)

-- Conjure: macros and status ----------------------------------------------------

test("MTF writes water and food macros in the character tab", function()
    local state = mage()
    state.put(0, 1, WATER_PURIFIED, 8)
    state.emit("BAG_UPDATE_DELAYED")
    equal(macroBody(state, "! Water"), table.concat({
        "#showtooltip item:" .. WATER_PURIFIED,
        "/use [btn:2] Conjure Water(Rank 3)",
        "/stopmacro [btn:2]",
        "/use item:8079", "/use item:8078", "/use item:8077", "/use item:3772", "/use item:2136",
        "/use item:2288", "/use item:5350"}, "\n"))
    contains(macroBody(state, "! Food"), "/use [btn:2] Conjure Food(Rank 3)")
    equal(state.macros[1].icon, 134400)
end)
test("the macros follow your target's level, and turning them off deletes them", function()
    local state = mage()
    state.units.target = friend(10).target
    state.emit("PLAYER_TARGET_CHANGED")
    contains(macroBody(state, "! Water"), "Conjure Water(Rank 2)")
    state.settings.MTF_CONJURE_MACROS:SetValue(false)
    equal(#state.macros, 0)
    state.settings.MTF_CONJURE_MACROS:SetValue(true)
    equal(#state.macros, 3, "water, food, and both; no gem spell yet")
end)
test("/mtf conjure reports what you carry and the share size", function()
    local state = mage()
    state.put(0, 1, WATER_PURIFIED, 8)
    state.put(0, 2, WATER_FRESH, 3)
    state.emit("BAG_UPDATE_DELAYED")
    state.clear()
    state.slash("conjure")
    equal(state.messages[1], "MTF: Water: 8 Conjured Purified Water (best), 11 in all.")
    equal(state.messages[2], "MTF: Food: none.")
    equal(state.messages[4], "MTF: Share stack size: 10.")
end)
test("the conjure bar has a size setting, applied out of combat", function()
    local state = mage()
    local bar = state.env.MageToolsForeverConjure
    equal(state.mtf.db.conjure.scale, 100)
    state.combat = true
    state.settings.DYRE_MAGETOOLSFOREVER_CONJURE_SCALE:SetValue(60)
    equal(bar.scale or 1, 1, "the bar holds secure buttons: not in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(bar.scale, 0.6)
    state.settings.DYRE_MAGETOOLSFOREVER_CONJURE_SCALE:SetValue(62)
    equal(state.mtf.db.conjure.scale, 60, "in steps of 5")
    local saved = mage({db = {conjure = {scale = "huge"}}})
    equal(saved.mtf.db.conjure.scale, 100)
end)
test("MTF 1.1's shield, reminder, and chime settings stay exactly as they were", function()
    -- Dyre's Shields Up and Dyre's Buff Reminders copy them once per character,
    -- also when a player installs them later, so MTF never changes or drops them.
    local function old()
        return {
            locked = true,
            shield = {enabled = false, number = false, breakSound = true, breakSoundKey = "magical", scale = 80,
                textScale = 120, iconScale = 90, locked = true,
                position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 400, y = 300}},
            reminders = {enabled = true, group = false, spells = {intellect = true, armor = false, dampen = true},
                last = {armor = "Mage Armor"},
                icons = {intellect = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 10, y = 20},
                    scale = 150}}},
            chimes = {enabled = true, lead = 1, spells = {blink = true, coldsnap = true},
                sounds = {blink = "shortbellstrike"}, learned = {blink = 14}, sound = "kazoo", unknown = "kept"},
        }
    end
    local state = mage({db = old()})
    local expected = old()
    local function same(actual, wanted, path)
        equal(type(actual), type(wanted), path)
        if type(wanted) == "table" then
            for key, value in pairs(wanted) do same(actual[key], value, path .. "." .. key) end
            for key in pairs(actual) do equal(wanted[key] ~= nil, true, path .. "." .. key .. " added") end
        else
            equal(actual, wanted, path)
        end
    end
    for _, key in ipairs({"shield", "reminders", "chimes"}) do
        same(state.mtf.db[key], expected[key], key)
    end
    state.slash("unlock")
    state.slash("lock")
    state.slash("reset")
    for _, key in ipairs({"shield", "reminders", "chimes"}) do
        same(state.mtf.db[key], expected[key], key .. " after unlock, lock, and reset")
    end
end)
test("one lock for every frame; older saved per-frame locks give way to it", function()
    local state = mage({db = {conjure = {locked = false}}})
    equal(state.mtf.db.locked, true)
    equal(state.settings.MTF_CONJURE_LOCKED, nil, "no per-frame switches")
    equal(state.settings.MTF_SHIELD_LOCKED, nil)
    local bar = state.env.MageToolsForeverConjure
    bar.scripts.OnDragStart(bar)
    equal(bar.moving, nil, "locked: not dragged")
end)
test("/mtf reset moves the conjure bar back, after combat if needed", function()
    local state = mage({db = {conjure = {position = {point = "TOP", relativePoint = "TOP", x = 1, y = 2}}}})
    local bar = state.env.MageToolsForeverConjure
    equal(bar.points[1][1], "TOP")
    state.combat = true
    state.slash("reset")
    equal(state.last(), "MTF: MTF frames move back to their default places after combat.", "one message")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(bar.points[1][1], "CENTER")
end)

-- Timers -----------------------------------------------------------------------

local function advance(state, seconds)
    state.now = state.now + seconds
    state.runTimers()
end

-- Portals ---------------------------------------------------------------------------

local TELEPORT_STORMWIND, TELEPORT_IRONFORGE, PORTAL_IRONFORGE = 3561, 3562, 11416
local RUNE_TELEPORTATION, RUNE_PORTALS = 17031, 17032

local function portalButtons(state)
    local shown = {}
    for index = 1, 12 do
        local button = state.env["MageToolsForeverPortal" .. index]
        if button.shown then shown[#shown + 1] = button end
    end
    return shown
end

test("the portal bar has a button for each teleport and portal you know, teleports first", function()
    local state = mage({known = {[PORTAL_IRONFORGE] = true, [TELEPORT_IRONFORGE] = true,
        [TELEPORT_STORMWIND] = true}})
    local buttons = portalButtons(state)
    equal(#buttons, 3)
    equal(buttons[1].attributes.spell1, TELEPORT_STORMWIND)
    equal(buttons[2].attributes.spell1, TELEPORT_IRONFORGE)
    equal(buttons[3].attributes.spell1, PORTAL_IRONFORGE)
    equal(buttons[1].attributes.type1, "spell")
    equal(state.env.MageToolsForeverPortals.shown, true)
end)
test("rune counts are shown but a count of zero never blocks a portal", function()
    local state = mage({known = {[PORTAL_IRONFORGE] = true, [TELEPORT_IRONFORGE] = true}})
    local buttons = portalButtons(state)
    equal(buttons[1].count.text, 0, "no runes")
    equal(buttons[2].attributes.type1, "spell", "still castable with no runes (legacy talents)")
    equal(buttons[2].attributes.spell1, PORTAL_IRONFORGE)
    state.put(0, 1, RUNE_PORTALS, 3)
    state.emit("BAG_UPDATE_DELAYED")
    equal(buttons[2].count.text, 3)
    equal(buttons[1].count.text, 0)
end)
test("the portal bar hides with nothing known, unless unlocked, and follows its switch", function()
    local state = mage()
    equal(state.env.MageToolsForeverPortals.shown, false)
    state.slash("unlock")
    equal(state.env.MageToolsForeverPortals.shown, true, "shown to be placed")
    state.slash("lock")
    equal(state.env.MageToolsForeverPortals.shown, false)
    state.known[TELEPORT_IRONFORGE] = true
    state.emit("SPELLS_CHANGED")
    equal(state.env.MageToolsForeverPortals.shown, true)
    state.settings.MTF_PORTALS_ENABLED:SetValue(false)
    equal(state.env.MageToolsForeverPortals.shown, false)
end)
test("a spell learned in combat reaches the bar after combat", function()
    local state = mage()
    state.combat = true
    state.known[TELEPORT_IRONFORGE] = true
    state.emit("SPELLS_CHANGED")
    equal(#portalButtons(state), 0, "no secure changes in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(portalButtons(state)[1].attributes.spell1, TELEPORT_IRONFORGE)
end)
test("an opened portal is told to the group once, and never when alone", function()
    local state = mage({known = {[PORTAL_IRONFORGE] = true}})
    state.cast(PORTAL_IRONFORGE)
    equal(#state.sent, 0, "alone")
    state.group = "party"
    state.cast(TELEPORT_IRONFORGE)
    equal(#state.sent, 0, "a teleport is yours alone")
    state.cast(PORTAL_IRONFORGE)
    equal(#state.sent, 1)
    equal(state.sent[1].chatType, "PARTY")
    equal(state.sent[1].message, "A portal to Ironforge is open. Step through before it closes.")
    state.cast(PORTAL_IRONFORGE)
    equal(#state.sent, 1, "once per cast, not repeated")
    advance(state, 6)
    state.group = "raid"
    state.mtf.db.announce.portalGroupText = "Hop in, %D bound!"
    state.cast(PORTAL_IRONFORGE)
    equal(state.sent[2].chatType, "RAID")
    equal(state.sent[2].message, "Hop in, Ironforge bound!")
    advance(state, 6)
    state.mtf.db.announce.portalGroup = false
    state.cast(PORTAL_IRONFORGE)
    equal(#state.sent, 2, "its switch turns it off")
end)
test("a teleport emotes at your next key press or click, and its switch turns it off", function()
    local state = mage({known = {[TELEPORT_IRONFORGE] = true}})
    state.cast(TELEPORT_IRONFORGE)
    equal(#state.sent, 0, "emotes wait for a key press or click")
    state.zone = "Ironforge"
    state.units.player.surname = "Smith"
    state.press()
    equal(#state.sent, 1)
    equal(state.sent[1].chatType, "EMOTE")
    equal(state.sent[1].message, "teleports to Ironforge.")
    state.press()
    equal(#state.sent, 1, "once per cast")
    state.mtf.db.announce.teleportEmoteText = "brings %T to %Z"
    state.cast(TELEPORT_IRONFORGE)
    advance(state, 61)
    state.press()
    equal(#state.sent, 1, "too late after the cast")
    state.cast(TELEPORT_IRONFORGE)
    state.press()
    equal(state.sent[2].message, "brings Dyre Smith to Ironforge", "%T is you, %Z your zone when sent")
    state.mtf.db.announce.teleportEmote = false
    state.cast(TELEPORT_IRONFORGE)
    state.press()
    equal(#state.sent, 2)
end)
test("/mtf debug_portals lists each spell and the runes", function()
    local state = mage({known = {[TELEPORT_IRONFORGE] = true}})
    state.clear()
    state.slash("debug_portals")
    local all = table.concat(state.messages, "|")
    contains(all, "debug_portals teleport Ironforge spell=3562 name=Teleport: Ironforge known=true")
    contains(all, "debug_portals portal Orgrimmar spell=11417 name=nil known=false")
    contains(all, "debug_portals runes teleportation=0 portals=0 bar=true")
end)

-- Announce page ------------------------------------------------------------------------

test("the Announce page edits each message, Escape undoes, and Defaults restores", function()
    local state = mage()
    local page = state.mtf.announcePage
    page:OnRefresh()
    local names = {}
    for _, row in ipairs(page.rows) do names[#names + 1] = row.switch end
    equal(table.concat(names, ","), "waterWhisper,foodWhisper,bothWhisper,portalGroup,teleportEmote")
    local portal = page.rows[4]
    equal(portal.check.checked, true)
    equal(portal.edit.text, state.mtf.ANNOUNCE_DEFAULTS.portalGroupText)
    portal.edit:SetText("Portal to %D,\nall aboard")
    portal.edit.scripts.OnEnterPressed(portal.edit)
    equal(state.mtf.db.announce.portalGroupText, "Portal to %D, all aboard", "one chat line")
    portal.edit:SetText("oops")
    portal.edit.scripts.OnEscapePressed(portal.edit)
    equal(portal.edit.text, "Portal to %D, all aboard")
    portal.edit:SetText("   ")
    portal.edit.scripts.OnEditFocusLost(portal.edit)
    equal(state.mtf.db.announce.portalGroupText, state.mtf.ANNOUNCE_DEFAULTS.portalGroupText, "empty is the default")
    state.mtf.db.announce.foodWhisper = false
    page:OnDefault()
    equal(state.mtf.db.announce.foodWhisper, true)
end)
test("an old single whisper switch carries over to each trade whisper", function()
    local state = mage({db = {conjure = {whisper = false}}})
    equal(state.mtf.db.announce.waterWhisper, false)
    equal(state.mtf.db.announce.bothWhisper, false)
    equal(state.mtf.db.announce.portalGroup, true, "the portal message is new")
    equal(state.mtf.db.conjure.whisper, nil)
end)
test("the default messages are plain and name no AddOn", function()
    local state = mage()
    local defaults = state.mtf.ANNOUNCE_DEFAULTS
    equal(defaults.waterWhisperText, "Here's %C %I. Enjoy, %T!")
    equal(defaults.foodWhisperText, "Here's %C %I. Enjoy, %T!")
    equal(defaults.bothWhisperText, "Here's %I. Enjoy, %T!")
    equal(defaults.portalGroupText, "A portal to %D is open. Step through before it closes.")
    equal(defaults.teleportEmoteText, "teleports to %D.")
    local count = 0
    for key, text in pairs(defaults) do
        count = count + 1
        equal(text:find("Mage Tools Forever", 1, true), nil, key .. " names the AddOn")
        equal(text:find("(MTF)", 1, true), nil, key .. " names the AddOn")
        equal(state.mtf.db.announce[key], text, key .. " is the default on a new character")
    end
    equal(count, 5)
end)
test("an unedited old default becomes the new one, and a player's own text stays", function()
    local state = mage({db = {announce = {
        waterWhisperText = "Here's %C %I, conjured from pure arcane energy. Drink up, %T! Courtesy of Mage Tools Forever (MTF)",
        foodWhisperText = "Here's %C %I, conjured from thin air: no crumbs, no calories. Courtesy of Mage Tools Forever (MTF)",
        bothWhisperText = "Here's %I, conjured from pure arcane energy. Eat, drink, and be merry, %T! "
            .. "Courtesy of Mage Tools Forever (MTF)",
        portalGroupText = "A portal to %D shimmers open! Step through before it fades. - via Mage Tools Forever (MTF)",
        teleportEmoteText = "My own emote to %D",
        portalGroup = false,
    }}})
    local announce, defaults = state.mtf.db.announce, state.mtf.ANNOUNCE_DEFAULTS
    equal(announce.waterWhisperText, defaults.waterWhisperText)
    equal(announce.foodWhisperText, defaults.foodWhisperText)
    equal(announce.bothWhisperText, defaults.bothWhisperText)
    equal(announce.portalGroupText, defaults.portalGroupText)
    equal(announce.teleportEmoteText, "My own emote to %D", "the player's own text stays")
    equal(announce.portalGroup, false, "the switches stay")
    local old = state.mtf.SanitizeDB({announce = {
        teleportEmoteText = "summons powerful arcane energies to whisk themselves away to %Z. - via Mage Tools Forever (MTF)",
        waterWhisperText = "Here's %C %I. Courtesy of Mage Tools Forever (MTF)",
    }}).announce
    equal(old.teleportEmoteText, "teleports to %D.")
    equal(old.waterWhisperText, "Here's %C %I. Courtesy of Mage Tools Forever (MTF)", "an edited text stays as typed")
end)

-- Dyre's Toolkit widgets (2.0) -------------------------------------------------------

local function countMessages(state, fragment)
    local found = 0
    for _, message in ipairs(state.messages) do
        if message:find(fragment, 1, true) then found = found + 1 end
    end
    return found
end
local function widgets(state)
    local byKey = {}
    for _, widget in ipairs(state.toolkit.Widgets("MageToolsForever")) do
        byKey[widget.dyre.widgetKey] = widget
    end
    return byKey
end
local function same(actual, expected, what)
    for key, value in pairs(expected) do
        if type(value) == "table" then
            same(actual[key], value, what .. "." .. key)
        else
            equal(actual and actual[key], value, what .. "." .. key)
        end
    end
end

-- Polymorph moved to Dyre's Debuff Tracker (1.6.0; John, 2026-11-20) -------------------

local POLYMORPH = 118
local INSTALL_DDT = "MTF: Install Dyre's Debuff Tracker from CurseForge for the Polymorph bar."
-- An MTF 1.5 character's Polymorph data, as its SanitizeDB saved it.
local function oldPolymorphDB(enabled)
    return {
        polymorph = {enabled = enabled, position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 250, y = 500},
            scale = 110, mark = false, macro = true, opacity = 60, width = 300, height = 24, textScale = 150},
        announce = {polymorphGroup = false, polymorphGroupText = "Moo %T"},
        ownedMacros = {["! Polymorph"] = true, ["! Water"] = true},
    }
end
local function saidStarting(state, prefix)
    local count = 0
    for _, message in ipairs(state.messages) do
        if message:sub(1, #prefix) == prefix then count = count + 1 end
    end
    return count
end

test("MTF draws no Polymorph bar, writes no \"! Polymorph\", and claims no control engine", function()
    local state = mage({known = {[POLYMORPH] = true}})
    equal(state.mtf.available, true)
    equal(state.env.MageToolsForeverPolymorph, nil, "no click frame")
    equal(state.env.MageToolsForeverPolymorphBar, nil, "no bar")
    equal(macroBody(state, "! Polymorph"), nil, "no macro")
    for _, name in ipairs({"InitializePolymorph", "RefreshPolymorph", "ApplyPolymorphMacro", "ReportPolymorphDebug",
            "ReportFocusDebug", "ResetFocus"}) do
        equal(state.mtf[name], nil, name .. " is gone")
    end
    for _, command in ipairs({"debug_polymorph", "debug_focus", "reset_focus"}) do
        state.slash(command)
        contains(state.last(), "Use /mtf", command .. " shows the usage")
    end
    equal(state.last():find("polymorph", 1, true), nil, "the usage names no Polymorph command")
end)

test("MTF keeps its saved Polymorph data exactly as saved, for Dyre's Debuff Tracker", function()
    local saved = oldPolymorphDB(true)
    local state = mage({known = {[POLYMORPH] = true}, db = saved})
    local db = state.mtf.db
    same(db.polymorph, oldPolymorphDB(true).polymorph, "polymorph")
    equal(db.announce.polymorphGroup, false)
    equal(db.announce.polymorphGroupText, "Moo %T")
    equal(db.ownedMacros["! Polymorph"], true, "the macro record stays")
    -- Damaged data is not repaired (no reader in MTF): only a table is kept.
    equal(state.mtf.SanitizeDB({polymorph = {width = "wide"}}).polymorph.width, "wide")
    equal(state.mtf.SanitizeDB({polymorph = 5}).polymorph, nil)
    local fresh = state.mtf.SanitizeDB({})
    equal(fresh.polymorph, nil, "a new character has none")
    equal(fresh.announce.polymorphGroup, nil)
    equal(fresh.announce.polymorphGroupText, nil)
    equal(state.mtf.SanitizeDB({announce = {polymorphGroup = "x", polymorphGroupText = 5}}).announce.polymorphGroup,
        nil)
end)

-- Lead, 2026-11-20: one line about the move, never two. With Dyre's Debuff
-- Tracker loaded, its own "Copied ..." line; without it, MTF's install line.
local function mtfPolymorphLines(state)
    local found = {}
    for _, message in ipairs(state.messages) do
        if message:sub(1, 5) == "MTF: " and message:find("Polymorph", 1, true) then
            found[#found + 1] = message
        end
    end
    return found
end

test("with Dyre's Debuff Tracker loaded, MTF says nothing about the Polymorph move", function()
    for _, enabled in ipairs({true, false}) do
        local state = mage({known = {[POLYMORPH] = true}, db = oldPolymorphDB(enabled),
            companions = {"DyresShieldsUp", "DyresBuffReminders", "DyresDebuffTracker"}})
        equal(#mtfPolymorphLines(state), 0, "no MTF line, bar " .. tostring(enabled))
        equal(state.mtf.db.polymorphMoved, nil, "nothing recorded")
    end
end)

test("without Dyre's Debuff Tracker MTF says only the install line, once per login", function()
    for _, db in ipairs({oldPolymorphDB(true), oldPolymorphDB(false), {}}) do
        local state = mage({known = {[POLYMORPH] = true}, db = db,
            companions = {"DyresShieldsUp", "DyresBuffReminders"}})
        local lines = mtfPolymorphLines(state)
        equal(#lines, 1, "one line")
        equal(lines[1], INSTALL_DDT)
        state.clear()
        state.slash("unlock")
        state.slash("lock")
        equal(#mtfPolymorphLines(state), 0, "only at login")
    end
end)

test("MTF 1.2.3's own focus flag is carried to the Toolkit once, then cleared", function()
    local state = mage({classic = true, accountDB = {focusWorks = true}})
    equal(state.env.DyresToolkitDB.focusWorks, true, "carried over")
    equal(state.env.MageToolsForeverAccountDB.focusWorks, nil, "and cleared")
    local damaged = mage({classic = true, accountDB = {focusWorks = "yes"}})
    equal(damaged.env.DyresToolkitDB.focusWorks, nil)
    equal(damaged.env.MageToolsForeverAccountDB.focusWorks, nil)
end)

test("the login banner follows the Toolkit's welcome switch", function()
    -- John, 2026-11-23: "toggle off our welcome messages unless there is an error/problem".
    local banner = " by Dyre"
    for _, options in ipairs({{noToolkit = true}, {welcome = "none"}, {welcome = true}}) do
        local state = mage(options)
        equal(countMessages(state, banner), 1, "banner shown")
    end
    local shown = mage({welcome = true})
    equal(countMessages(shown, "Type /mtf to open the settings."), 1, "ready hint shown")
    local hidden = mage({welcome = false})
    equal(hidden.mtf.available, true)
    equal(countMessages(hidden, banner), 0, "no banner")
    equal(countMessages(hidden, "Type /mtf to open the settings."), 0, "no ready hint")
    -- A problem still shows with the switch off.
    local wrong = mage({welcome = false, remove = {"InitiateTrade"}})
    equal(wrong.mtf.available, false)
    equal(countMessages(wrong, banner), 0, "no banner")
    equal(countMessages(wrong, "it lacks InitiateTrade"), 1, "the problem shows")
end)

test("without Dyre's Toolkit 2.5 MTF stays off and says once what to install", function()
    for _, options in ipairs({{noToolkit = true}, {oldToolkit = true}}) do
        local state = mage(options)
        equal(state.mtf.available, false)
        equal(countMessages(state, "needs Dyre's Toolkit:"), 1, "said once")
        for _, message in ipairs(state.messages) do
            if message:find("needs Dyre's Toolkit", 1, true) then
                contains(message, "MTF: ")
                contains(message, "CurseForge")
                equal(message:lower():find("github", 1, true), nil, "CurseForge only")
            end
        end
        equal(state.env.MageToolsForeverConjure, nil, "no frames")
    end
end)
test("every movable MTF frame is a Dyre's Toolkit widget with the right mouse", function()
    local state = mage({known = {[POLYMORPH] = true}})
    local env, byKey = state.env, widgets(state)
    local want = {
        conjure = {env.MageToolsForeverConjure, "always"},
        portals = {env.MageToolsForeverPortals, "always"},
    }
    local count = 0
    for key, entry in pairs(want) do
        count = count + 1
        equal(byKey[key], entry[1], key .. " is the frame MTF made")
        equal(byKey[key].dyre.mouseMode, entry[2], key .. " mouse")
    end
    equal(#state.toolkit.Widgets("MageToolsForever"), count, "no others")
    local member
    for _, info in ipairs(state.toolkit.AddOns()) do
        if info.addon == "MageToolsForever" then member = info end
    end
    equal(member.title, "Mage Tools Forever", "registered with the toolkit")
    equal(state.mtf.CreateMover, nil, "no layout code of MTF's own")
    equal(state.mtf.RegisterMovable, nil)
    equal(state.mtf.ResizeFromCenter, nil)
    equal(state.mtf.RefreshGrid, nil)
end)
test("existing saved places and sizes load unchanged", function()
    local saved = {
        conjure = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 600, y = 250}, scale = 80},
        portals = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 300, y = 200}, scale = 120},
    }
    local copy = {
        conjure = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 600, y = 250}, scale = 80},
        portals = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 300, y = 200}, scale = 120},
    }
    local state = mage({known = {[TELEPORT_STORMWIND] = true}, db = saved})
    same(state.mtf.db, copy, "db")
    local env = state.env
    local function at(frame, entry, what)
        local point = frame.points[#frame.points]
        equal(point[3], entry.position.relativePoint, what .. " relative point")
        equal(point[4], entry.position.x, what .. " x")
        equal(point[5], entry.position.y, what .. " y")
        equal(frame:GetScale(), entry.scale / 100, what .. " scale")
    end
    at(env.MageToolsForeverConjure, copy.conjure, "conjure")
    at(env.MageToolsForeverPortals, copy.portals, "portals")
end)
test("a drag that starts on a conjure or portal button drags its bar", function()
    local state = mage({known = {[TELEPORT_STORMWIND] = true}})
    local bar, water = state.env.MageToolsForeverConjure, state.env.MageToolsForeverWater
    water.scripts.OnDragStart(water)
    equal(bar.moving, nil, "locked: no drag")
    state.slash("unlock")
    water.scripts.OnDragStart(water)
    equal(bar.moving, true, "the bar moves")
    water.scripts.OnDragStop(water)
    equal(state.mtf.db.conjure.position.point, "CENTER", "saved by the toolkit")
    local portals, button = state.env.MageToolsForeverPortals, state.env.MageToolsForeverPortal1
    button.scripts.OnDragStart(button)
    equal(portals.moving, true)
    button.scripts.OnDragStop(button)
    equal(water.scripts.PostClick ~= nil, true, "the buttons still click")
end)

test("the conjure and portal bars resize from their centers, and their Bar size has a mark at 100", function()
    local here = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 700, y = 300}
    local state = mage({known = {[TELEPORT_STORMWIND] = true},
        db = {conjure = {position = here}, portals = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT",
            x = 200, y = 150}}}})
    local function near(a, b, what) equal(math.abs(a - b) < 0.01, true, what .. ": " .. a .. " vs " .. b) end
    local function at(frame, x, y, what)
        local fx, fy = state.absCenter(frame)
        near(fx, x, what .. " x")
        near(fy, y, what .. " y")
    end
    local conjure, portals = state.env.MageToolsForeverConjure, state.env.MageToolsForeverPortals
    at(conjure, 700, 300, "conjure at first")
    state.settings.DYRE_MAGETOOLSFOREVER_CONJURE_SCALE:SetValue(150)
    at(conjure, 700, 300, "conjure at 150%")
    state.settings.DYRE_MAGETOOLSFOREVER_CONJURE_SCALE:SetValue(50)
    at(conjure, 700, 300, "conjure at 50%")
    near(state.mtf.db.conjure.position.x * 0.5, 700, "conjure saved where it is")
    at(portals, 200, 150, "portals at first")
    state.settings.DYRE_MAGETOOLSFOREVER_PORTALS_SCALE:SetValue(130)
    at(portals, 200, 150, "portals at 130%")
    local width = portals.width
    state.known[TELEPORT_IRONFORGE] = true
    state.known[PORTAL_IRONFORGE] = true
    state.emit("SPELLS_CHANGED")
    equal(portals.width > width, true, "wider with more spells")
    at(portals, 200, 150, "portals with more spells grow from the center")
    for _, name in ipairs({"Conjure", "Portals"}) do
        local mark
        for _, initializer in ipairs(state.categories[name].initializers) do
            if initializer.setting.name == "Bar size" then mark = initializer.dyreDefault end
        end
        equal(mark and mark.default, 100, name .. ": Bar size has its mark at 100")
    end
end)
-- MTF's macro text ------------------------------------------------------------------

-- Every macro body and click macrotext MTF writes, for a Mage who knows
-- every kind.
local function writtenMacroText()
    local state = mage({known = {[759] = true, [POLYMORPH] = true}})
    local texts = {}
    for _, macro in ipairs(state.macros) do
        texts[#texts + 1] = {where = "macro " .. macro.name, text = macro.body}
    end
    for _, frame in ipairs(state.frames) do
        for key, value in pairs(frame.attributes or {}) do
            if type(key) == "string" and key:find("^macrotext") and type(value) == "string" then
                texts[#texts + 1] = {where = tostring(frame.name) .. " " .. key, text = value}
            end
        end
    end
    return texts
end
test("MTF's macros use /use, never /cast, and every @focus tests harm, noharm, or dead", function()
    -- Author: "use /use instead of cast; every character counts". John, 2026-11-12:
    -- "exists is a no-op, drop it": harm is false with no unit. So every @focus
    -- clause must test the unit with harm, noharm, or dead, never stand alone.
    local texts = writtenMacroText()
    local seen = {}
    for _, entry in ipairs(texts) do
        seen[entry.where] = true
        for line in entry.text:gmatch("[^\n]+") do
            equal(line:find("^/cast "), nil, entry.where .. ": " .. line)
            for clause in line:gmatch("%[([^%]]*)%]") do
                if clause:find("@focus", 1, true) then
                    local tested = false
                    for word in clause:gmatch("[^,]+") do
                        if word == "harm" or word == "noharm" or word == "dead" then
                            tested = true
                        end
                    end
                    equal(tested, true, entry.where .. ": " .. line)
                end
            end
        end
        equal(#entry.text <= 255 or not entry.where:find("^macro "), true, entry.where .. " fits a macro")
    end
    for _, where in ipairs({"macro ! Water", "macro ! Food", "macro ! Food & Water", "macro ! Mana Gem"}) do
        equal(seen[where], true, where .. " was checked")
    end
    equal(seen["macro ! Polymorph"], nil, "Dyre's Debuff Tracker's macro now")
end)

-- Settings pages ----------------------------------------------------------------

test("the settings have a main page and a page per module", function()
    local state = mage()
    local main = state.categories["Mage Tools Forever"]
    equal(main.parent, state.categories["Dyre's AddOns"], "under Dyre's Toolkit's home")
    equal(state.registered, state.categories["Dyre's AddOns"])
    equal(main.initializers[1].setting.variable, "MTF_CONJURE_ENABLED")
    -- One plain sentence (John, 2026-11-27: the follow-on text was "clearly not meant for users").
    equal(main.initializers[1].tooltip,
        "A bar with water, food, and mana gem buttons: left-click uses or trades, right-click conjures.")
    equal(main.initializers[2].setting.variable, "MTF_PORTALS_ENABLED")
    equal(main.initializers[3], nil,
        "no switches for what moved to Dyre's Shields Up, Dyre's Buff Reminders, and Dyre's Debuff Tracker")
    equal(state.categories["Crowd Control"].parent, main)
    equal(state.categories.Reminders.parent, main)
    equal(state.categories.Portals.parent, main)
    equal(state.categories.Announce.parent, main)
    equal(state.categories.Announce.frame, state.mtf.announcePage, "a canvas page")
    equal(state.categories.Conjure.parent, main)
    equal(state.categories["Shield display"].parent, main)
    equal(state.categories.Chimes.parent, main)
    equal(state.categories.Procs.parent, main)
    state.settings.MTF_CONJURE_ENABLED:SetValue(false)
    equal(state.env.MageToolsForeverConjure.shown, false)
end)
test("the Shield display, Reminders, Chimes, and Polymorph pages link to their Dyre's AddOns", function()
    local function link(state, title)
        local page = state.categories[title]
        equal(#page.initializers, 0, title .. ": no settings of MTF's own")
        local found
        for _, item in ipairs(page.headings) do
            if item.button then found = item end
        end
        return found
    end
    local state = mage({companions = {"DyresShieldsUp", "DyresBuffReminders"}})
    local shield = link(state, "Shield display")
    equal(shield.buttonText, "Open Shield settings")
    contains(shield.tooltip, "Opens Dyre's Shields Up, which shows your shields as rings")
    equal(shield.modifyPredicates[1](), true, "usable: Dyre's Shields Up has joined the toolkit")
    shield.onClick()
    equal(state.openedCompanion[1], "DyresShieldsUp", "opens Dyre's Shields Up's own page")
    local reminders = link(state, "Reminders")
    equal(reminders.buttonText, "Open Buff Reminders settings")
    contains(reminders.tooltip, "Dampen or Amplify Magic")
    reminders.onClick()
    equal(state.openedCompanion[2], "DyresBuffReminders")
    local chimes = link(state, "Chimes")
    contains(chimes.tooltip, "Blink, Frost Nova")
    chimes.onClick()
    equal(state.openedCompanion[3], "DyresBuffReminders")
    state.combat = true
    shield.onClick()
    equal(#state.openedCompanion, 3, "never in combat")
    contains(state.last(), "out of combat")
    -- Without them: greyed, and a click says what to install.
    local alone = mage()
    local missing = link(alone, "Shield display")
    equal(missing.modifyPredicates[1](), false, "greyed out")
    equal(missing.tooltip, "Install Dyre's Shields Up from CurseForge for the shield display.")
    alone.clear()
    missing.onClick()
    contains(alone.last(), "Install Dyre's Shields Up from CurseForge for the shield display.")
    equal(link(alone, "Chimes").tooltip,
        "Install Dyre's Buff Reminders from CurseForge for buff reminders, cooldown chimes, and proc arcs.")
    -- The Polymorph page (1.6.0): one row that opens Dyre's Debuff Tracker's settings.
    local ddt = mage({companions = {"DyresDebuffTracker"}})
    local polymorph = link(ddt, "Crowd Control")
    equal(polymorph.name, "Crowd Control", "the section's name")
    equal(polymorph.buttonText, "Open Debuff Tracker settings")
    contains(polymorph.tooltip, "Opens Dyre's Debuff Tracker, which shows your Polymorph's time left")
    equal(polymorph.modifyPredicates[1](), true)
    polymorph.onClick()
    equal(ddt.openedCompanion[1], "DyresDebuffTracker", "opens Dyre's Debuff Tracker's own page")
    local noTracker = link(alone, "Crowd Control")
    equal(noTracker.modifyPredicates[1](), false, "greyed out without it")
    equal(noTracker.tooltip, "Install Dyre's Debuff Tracker from CurseForge for the Polymorph bar.")
    alone.clear()
    noTracker.onClick()
    contains(alone.last(), "Install Dyre's Debuff Tracker from CurseForge for the Polymorph bar.")
end)
test("the companion pages show the companions' own settings through the Toolkit", function()
    -- John, 2026-11-26: "surface every setting in the wrapped addon's settings, and just
    -- pass-through the setting to the wrapped addon".
    local function buttons(page)
        local found = 0
        for _, item in ipairs(page.headings or {}) do
            if item.button then found = found + 1 end
        end
        return found
    end
    local want = {
        {"Shield display", "DyresShieldsUp", "shield", "Open Shield settings"},
        {"Reminders", "DyresBuffReminders", "reminders", "Open Buff Reminders settings"},
        {"Chimes", "DyresBuffReminders", "chimes", "Open Buff Reminders settings"},
        {"Procs", "DyresBuffReminders", "procs", "Open Buff Reminders settings"},
        {"Procs", "DyresDebuffTracker", "cues", "Open Debuff Tracker settings"},
        {"Crowd Control", "DyresDebuffTracker", "control", "Open Debuff Tracker settings"},
    }
    -- The link buttons on a page, in order.
    local function buttonList(page)
        local found = {}
        for _, item in ipairs(page.headings or {}) do
            if item.button then found[#found + 1] = item end
        end
        return found
    end
    -- Each page's sections, in order: the Procs page holds two.
    local onPage, place = {}, {}
    for i, entry in ipairs(want) do
        onPage[entry[1]] = (onPage[entry[1]] or 0) + 1
        place[i] = onPage[entry[1]]
    end
    -- The companion has its section: its rows, and no link from MTF.
    local rows = mage({sections = "rows", companions = {"DyresShieldsUp", "DyresBuffReminders", "DyresDebuffTracker"}})
    equal(#rows.pageCalls, #want, "one section per page")
    equal(#rows.masterCalls, 0, "no top switches below SETTINGS_SECTIONS_VERSION 3")
    for i, entry in ipairs(want) do
        local call = rows.pageCalls[i]
        equal(call.category, rows.categories[entry[1]], entry[1] .. ": on its own page")
        equal(call.opts.addon, entry[2])
        equal(call.opts.key, entry[3])
        equal(call.opts.host, "MageToolsForever")
        equal(call.opts.part, nil, entry[1] .. ": the whole section below version 3")
        equal(call.opts.link.addon, entry[2], "the link as the fallback")
        equal(call.opts.link.button, entry[4])
        equal(buttons(rows.categories[entry[1]]), 0, entry[1] .. ": no link drawn by MTF")
    end
    equal(rows.pageCalls[1].opts.link.missing, "Install Dyre's Shields Up from CurseForge for the shield display.")
    -- John, 2026-11-27: "add a primer-text to tell people what they get if they install it".
    local primers = {
        {"Ice Barrier, Mana Shield, Fire Ward, and Frost Ward", "Install Dyre's Shields Up from CurseForge."},
        {"Arcane Intellect, your armor", "Install Dyre's Buff Reminders from CurseForge."},
        {"Blink, Frost Nova", "Install Dyre's Buff Reminders from CurseForge."},
        {"Missile Barrage, Fingers of Frost, or Clearcasting", "Install Dyre's Buff Reminders from CurseForge."},
        {"Winter's Chill", "Install Dyre's Debuff Tracker from CurseForge."},
        {"\"! Polymorph\"", "Install Dyre's Debuff Tracker from CurseForge."},
    }
    for i, entry in ipairs(want) do
        local primer = rows.pageCalls[i].opts.primer
        equal(type(primer), "string", entry[1] .. ": a primer")
        equal(primer, rows.mtf.COMPANION_PRIMERS[entry[3]])
        contains(primer, primers[i][1])
        equal(primer:sub(-#primers[i][2]), primers[i][2], entry[1] .. ": ends with what to install")
        equal(#primer <= 400, true, entry[1] .. ": fits the Toolkit's box (400)")
        equal(primer:lower():find("github", 1, true), nil, "CurseForge only")
    end
    -- The real Toolkit, when it has the primer box: drawn only while the AddOn is not loaded.
    local function primerRow(page, text)
        for _, item in ipairs(page.headings or {}) do
            if item.template and (text == nil or item.data.text == text) then return item end
        end
    end
    local real = mage()
    if type(real.toolkit.AddSettingsPrimer) == "function" then
        for _, entry in ipairs(want) do
            local text = real.mtf.COMPANION_PRIMERS[entry[3]]
            equal(type(primerRow(real.categories[entry[1]], text)), "table",
                entry[1] .. " " .. entry[3] .. ": the primer box without the AddOn")
        end
        local loaded = mage({companions = {"DyresShieldsUp", "DyresBuffReminders", "DyresDebuffTracker"}})
        for _, entry in ipairs(want) do
            equal(primerRow(loaded.categories[entry[1]]), nil, entry[1] .. ": no primer with the AddOn")
        end
    end
    -- A Toolkit build with sections but no primer box: no primer passed.
    local plain = mage({sections = "rows", noPrimer = true})
    for i = 1, #want do
        equal(plain.pageCalls[i].opts.primer, nil)
    end
    -- The companion has no section (not loaded, or older): the Toolkit draws the link.
    local link = mage({sections = "link"})
    for i, entry in ipairs(want) do
        local page = link.categories[entry[1]]
        equal(buttons(page), onPage[entry[1]], entry[1] .. ": a link per section")
        equal(buttonList(page)[place[i]].buttonText, entry[4])
    end
    -- A Toolkit older than 2.17.0: the link, as before.
    local old = mage({sections = "none"})
    for i, entry in ipairs(want) do
        equal(buttons(old.categories[entry[1]]), onPage[entry[1]], entry[1] .. ": the links without AddSettingsSection")
        equal(buttonList(old.categories[entry[1]])[place[i]].buttonText, entry[4])
    end
end)
test("each companion's top switch is on MTF's top page, the rest on its own page", function()
    -- John, 2026-11-27: "the top-level disable for each section should be on the top-level MTF panel".
    local want = {
        {"Shield display", "DyresShieldsUp", "shield"},
        {"Reminders", "DyresBuffReminders", "reminders"},
        {"Chimes", "DyresBuffReminders", "chimes"},
        {"Procs", "DyresBuffReminders", "procs"},
        {"Procs", "DyresDebuffTracker", "cues"},
        {"Crowd Control", "DyresDebuffTracker", "control"},
    }
    local state = mage({sections = "rows", sectionsVersion = 3,
        companions = {"DyresShieldsUp", "DyresBuffReminders", "DyresDebuffTracker"}})
    local main = state.categories["Mage Tools Forever"]
    equal(#state.masterCalls, #want, "one top switch per section")
    equal(#state.pageCalls, #want, "one rest per section")
    for i, entry in ipairs(want) do
        local master, rest = state.masterCalls[i], state.pageCalls[i]
        equal(master.category, main, entry[1] .. ": its switch on MTF's top page")
        equal(type(master.layout), "table", "with the top page's layout")
        equal(master.opts.addon, entry[2])
        equal(master.opts.key, entry[3])
        equal(master.opts.host, "MageToolsForever")
        equal(master.opts.part, "master")
        equal(master.opts.link, nil, "no link on the top page")
        equal(master.opts.primer, nil, "no primer on the top page")
        equal(rest.category, state.categories[entry[1]], entry[1] .. ": the rest on its own page")
        equal(rest.opts.key, entry[3])
        equal(rest.opts.part, "rest")
        equal(type(rest.opts.link), "table", "the link as the fallback")
        equal(rest.opts.primer, state.mtf.COMPANION_PRIMERS[entry[3]])
    end
    -- After Conjure bar and Portal bar.
    equal(main.initializers[1].setting.variable, "MTF_CONJURE_ENABLED")
    equal(main.initializers[2].setting.variable, "MTF_PORTALS_ENABLED")
    -- Without the companions, the Toolkit adds no top switch; each page has the link.
    local alone = mage({sections = "link", sectionsVersion = 3})
    equal(#alone.masterCalls, #want, "asked for each")
    equal(#alone.categories["Mage Tools Forever"].initializers, 2, "only MTF's own switches")
    for _, entry in ipairs(want) do
        local found = 0
        for _, item in ipairs(alone.categories[entry[1]].headings) do
            if item.button then found = found + 1 end
        end
        equal(found, entry[1] == "Procs" and 2 or 1, entry[1] .. ": a link per section")
    end
end)
test("each companion page and its link take the owner's name for the section", function()
    -- John, 2026-11-27: "let's have the same name used consistently everywhere".
    local titles = {DyresShieldsUp = {shield = "Shields"}, DyresBuffReminders = {reminders = "Buffs",
        chimes = "Cooldowns", procs = "Proc alerts"}, DyresDebuffTracker = {cues = "Chill", control = "Crowd control"}}
    local state = mage({sections = "link", sectionTitles = titles})
    for _, title in ipairs({"Shields", "Buffs", "Cooldowns", "Proc alerts", "Crowd control"}) do
        equal(type(state.categories[title]), "table", title .. ": the owner's name")
    end
    local names = {}
    for _, item in ipairs(state.categories["Proc alerts"].headings) do
        if item.button then names[#names + 1] = item.name end
    end
    equal(names[1], "Proc alerts", "the link has the same name")
    equal(names[2], "Chill", "each section its own name")
    equal(state.categories.Conjure.parent, state.categories["Mage Tools Forever"], "MTF's own names stay")
    equal(type(state.categories.Portals), "table")
    -- Without the owners (or SettingsSectionTitle), the same words as fallbacks.
    local alone = mage({sections = "link"})
    for _, title in ipairs({"Shield display", "Reminders", "Chimes", "Procs", "Crowd Control"}) do
        equal(type(alone.categories[title]), "table", title .. ": the fallback name")
    end
    equal(alone.categories["Buff Reminders"], nil, "the old name is gone")
    equal(alone.categories["Cooldown Chimes"], nil)
    -- Each fallback link has its section's name, not an older label.
    local linkNames = {
        ["Shield display"] = {"Shield display"}, Reminders = {"Reminders"}, Chimes = {"Chimes"},
        Procs = {"Procs", "Debuff Cues"}, ["Crowd Control"] = {"Crowd Control"},
    }
    for page, want in pairs(linkNames) do
        local names = {}
        for _, item in ipairs(alone.categories[page].headings) do
            if item.button then names[#names + 1] = item.name end
        end
        equal(#names, #want, page .. ": a link per section")
        for i, name in ipairs(want) do
            equal(names[i], name, page .. ": the link's name")
        end
    end
end)
test("the conjure and portal bars' rows are greyed while the bar is off", function()
    -- John, 2026-11-27: "when the top-level is off, the settings that are controlling a disabled
    -- feature should be disabled too".
    local state = mage()
    local function rows(title)
        local found = {}
        for _, initializer in ipairs(state.categories[title].initializers) do
            if initializer.setting then found[initializer.setting.variable] = initializer end
        end
        return found
    end
    local function greyed(initializer)
        for _, predicate in ipairs(initializer.modifyPredicates or {}) do
            if predicate() == false then return true end
        end
        return false
    end
    local conjure = rows("Conjure")
    local share, shift, macros = conjure.MTF_CONJURE_SHARE_SIZE, conjure.MTF_CONJURE_SHIFT_TRADE,
        conjure.MTF_CONJURE_MACROS
    equal(greyed(share), false)
    equal(greyed(shift), false)
    if type(state.toolkit.BAR_LAYOUT_VERSION) == "number" then
        local conjureLayout = conjure.DYRE_MAGETOOLSFOREVER_CONJURE_ORIENTATION
        local portalLayout = rows("Portals").DYRE_MAGETOOLSFOREVER_PORTALS_ORIENTATION
        equal(greyed(conjureLayout), false)
        state.settings.MTF_CONJURE_ENABLED:SetValue(false)
        equal(greyed(conjureLayout), true, "Layout greyed with the bar off")
        equal(greyed(portalLayout), false, "the portal bar's Layout follows its own switch")
        state.settings.MTF_PORTALS_ENABLED:SetValue(false)
        equal(greyed(portalLayout), true)
        state.settings.MTF_PORTALS_ENABLED:SetValue(true)
        state.settings.MTF_CONJURE_ENABLED:SetValue(true)
    end
    state.settings.MTF_CONJURE_ENABLED:SetValue(false)
    equal(greyed(share), true, "share size greyed with the bar off")
    equal(greyed(shift), true, "Shift-click greyed with the bar off")
    equal(greyed(macros), false, "the macros work without the bar")
    state.settings.MTF_CONJURE_ENABLED:SetValue(true)
    equal(greyed(share), false, "usable again")
    -- The bars' size rows: the Toolkit's AddWidgetSettings opts.modify (2.17.0).
    local function sizeRow(title)
        for _, initializer in ipairs(state.categories[title].initializers) do
            if initializer.setting and initializer.setting.name == "Bar size" then
                return initializer
            end
        end
    end
    local conjureSize, portalSize = sizeRow("Conjure"), sizeRow("Portals")
    equal(type(conjureSize), "table", "a Bar size row")
    equal(type(portalSize), "table", "a Bar size row")
    if #conjureSize.modifyPredicates > 0 then
        state.settings.MTF_CONJURE_ENABLED:SetValue(false)
        equal(greyed(conjureSize), true, "the conjure bar's size greyed with it off")
        equal(greyed(portalSize), false, "the portal bar's size follows its own switch")
        state.settings.MTF_PORTALS_ENABLED:SetValue(false)
        equal(greyed(portalSize), true)
    end
end)
-- Dyre's Toolkit 2.18.0's button bars (BAR_LAYOUT_VERSION 1); the copy in
-- tests/toolkit may be older, so these run only with the feature.
local CONJURE_LAYOUT, PORTALS_LAYOUT = "DYRE_MAGETOOLSFOREVER_CONJURE_ORIENTATION",
    "DYRE_MAGETOOLSFOREVER_PORTALS_ORIENTATION"
local function hasBarLayout(state)
    return type(state.toolkit.BAR_LAYOUT_VERSION) == "number"
end
test("Layout Vertical stacks each bar's buttons top to bottom, in the same order, from the bar's center", function()
    -- A CurseForge player asked; John, 2026-11-27: "Yes, Toolkit feature".
    local state = mage({known = {[TELEPORT_STORMWIND] = true, [TELEPORT_IRONFORGE] = true, [PORTAL_IRONFORGE] = true},
        db = {conjure = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 700, y = 300}},
            portals = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 200, y = 150}}}})
    if not hasBarLayout(state) then return end
    local function near(a, b, what) equal(math.abs(a - b) < 0.01, true, what .. ": " .. a .. " vs " .. b) end
    local function at(frame, x, y, what)
        local fx, fy = state.absCenter(frame)
        near(fx, x, what .. " x")
        near(fy, y, what .. " y")
    end
    local conjure, portals = state.env.MageToolsForeverConjure, state.env.MageToolsForeverPortals
    local long, thick = 6 * 2 + 36 * 4 + 6 * 3, 6 * 2 + 36
    equal(state.mtf.db.conjure.orientation, nil, "a row by default")
    equal(conjure.width, long)
    equal(conjure.height, thick)
    state.settings[CONJURE_LAYOUT]:SetValue("vertical")
    equal(state.mtf.db.conjure.orientation, "vertical", "saved in MTF's settings")
    equal(conjure.width, thick, "one button wide")
    equal(conjure.height, long, "four buttons tall")
    for index, name in ipairs({WATER_BUTTON, FOOD_BUTTON, BOTH_BUTTON, GEM_BUTTON}) do
        local button = state.env[name]
        equal(#button.points, 1, name .. ": one point")
        local point = button.points[1]
        equal(point[1], "TOPLEFT", name)
        equal(point[2], conjure)
        equal(point[4], 6)
        equal(point[5], -(6 + (index - 1) * 42), name .. ": in the same order")
    end
    at(conjure, 700, 300, "the conjure bar keeps its center")
    state.settings[CONJURE_LAYOUT]:SetValue("horizontal")
    equal(conjure.width, long, "back to a row")
    equal(state.env[BOTH_BUTTON].points[1][4], 6 + 2 * 42)
    equal(state.env[BOTH_BUTTON].points[1][5], -6)
    at(conjure, 700, 300, "and still there")
    -- Portals: only the shown buttons, one per spell you know.
    equal(portals.width, 6 * 2 + 36 * 3 + 6 * 2)
    state.settings[PORTALS_LAYOUT]:SetValue("vertical")
    equal(portals.width, thick)
    equal(portals.height, 6 * 2 + 36 * 3 + 6 * 2)
    local buttons = portalButtons(state)
    equal(buttons[1].attributes.spell1, TELEPORT_STORMWIND, "teleports still first")
    for index, button in ipairs(buttons) do
        equal(button.points[#button.points][5], -(6 + (index - 1) * 42))
    end
    at(portals, 200, 150, "the portal bar keeps its center")
    state.known[TELEPORT_STORMWIND] = nil
    state.emit("SPELLS_CHANGED")
    equal(portals.height, 6 * 2 + 36 * 2 + 6, "shorter with fewer spells")
    equal(portals.width, thick)
    state.settings[CONJURE_LAYOUT]:SetValue("vertical")
    equal(state.mtf.db.portals.orientation, "vertical", "each bar has its own")
end)
test("a saved Vertical layout is drawn at login and survives the settings repair", function()
    local state = mage({known = {[TELEPORT_STORMWIND] = true, [TELEPORT_IRONFORGE] = true},
        db = {conjure = {orientation = "vertical"}, portals = {orientation = "vertical"}}})
    equal(state.mtf.db.conjure.orientation, "vertical", "kept by SanitizeDB")
    equal(state.mtf.db.portals.orientation, "vertical")
    if not hasBarLayout(state) then return end
    equal(state.env.MageToolsForeverConjure.width, 6 * 2 + 36)
    equal(state.env.MageToolsForeverConjure.height, 6 * 2 + 36 * 4 + 6 * 3)
    equal(state.env.MageToolsForeverPortals.height, 6 * 2 + 36 * 2 + 6)
end)
test("Layout is saved as vertical or nothing", function()
    local db = mage().mtf.SanitizeDB({conjure = {orientation = "diagonal"}, portals = {orientation = 5}})
    equal(db.conjure.orientation, nil)
    equal(db.portals.orientation, nil)
end)
test("a Layout change in combat waits for combat to end", function()
    local state = mage({known = {[TELEPORT_STORMWIND] = true, [TELEPORT_IRONFORGE] = true}})
    if not hasBarLayout(state) then return end
    state.combat = true
    state.settings[CONJURE_LAYOUT]:SetValue("vertical")
    state.settings[PORTALS_LAYOUT]:SetValue("vertical")
    equal(state.mtf.db.conjure.orientation, "vertical", "saved at once")
    equal(state.env[FOOD_BUTTON].points[1][5], -6, "the conjure buttons wait")
    equal(portalButtons(state)[2].points[1][5], -6, "the portal buttons wait")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.env[FOOD_BUTTON].points[1][5], -(6 + 42), "applied after combat")
    equal(portalButtons(state)[2].points[1][5], -(6 + 42))
    equal(state.env.MageToolsForeverConjure.width, 6 * 2 + 36)
    equal(state.env.MageToolsForeverPortals.width, 6 * 2 + 36)
end)
test("a profile copy with another Layout lays the conjure bar out again", function()
    local state = mage()
    if not hasBarLayout(state) then return end
    state.mtf.db.conjure.orientation = "vertical"
    state.mtf.ApplyProfile()
    equal(state.env.MageToolsForeverConjure.width, 6 * 2 + 36)
    equal(state.env[GEM_BUTTON].points[1][5], -(6 + 3 * 42))
end)
test("with a Toolkit older than 2.18.0 the bars stay rows, with no Layout row", function()
    local state = mage({noBarLayout = true, known = {[TELEPORT_STORMWIND] = true, [TELEPORT_IRONFORGE] = true},
        db = {conjure = {orientation = "vertical"}}})
    equal(state.settings[CONJURE_LAYOUT], nil, "no Layout row")
    equal(state.settings[PORTALS_LAYOUT], nil)
    equal(state.env.MageToolsForeverConjure.width, 6 * 2 + 36 * 4 + 6 * 3, "a row")
    equal(state.env[BOTH_BUTTON].points[1][1], "LEFT", "placed by MTF, as before")
    equal(state.env[BOTH_BUTTON].points[1][4], 6 + 2 * 42)
    equal(portalButtons(state)[2].points[1][1], "LEFT")
    equal(state.env.MageToolsForeverPortals.width, 6 * 2 + 36 * 2 + 6)
    equal(state.mtf.db.conjure.orientation, "vertical", "the saved choice stays for a newer Toolkit")
end)
test("a vertical bar's tooltips go beside it, on the side with more room", function()
    local state = mage({known = {[TELEPORT_STORMWIND] = true},
        db = {conjure = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 200, y = 300}},
            portals = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 900, y = 300}}}})
    local function anchor(button)
        button.scripts.OnEnter(button)
        return state.tooltip and state.tooltip.anchor
    end
    local water, portal = state.env[WATER_BUTTON], portalButtons(state)[1]
    equal(anchor(water), "ANCHOR_TOP", "over a row")
    equal(anchor(portal), "ANCHOR_TOP")
    if not hasBarLayout(state) then return end
    state.settings[CONJURE_LAYOUT]:SetValue("vertical")
    state.settings[PORTALS_LAYOUT]:SetValue("vertical")
    equal(anchor(water), "ANCHOR_RIGHT", "a bar on the left: to its right")
    equal(anchor(portal), "ANCHOR_LEFT", "a bar on the right: to its left")
end)
test("every tooltip MTF writes is one plain sentence", function()
    -- John, 2026-11-27: "every one of the tooltips seems to start with a good one sentence
    -- description, but then has nonsensical follow-on text that is clearly not meant for users".
    -- Only "Keep conjure macros" keeps a short second sentence: turning it off deletes the macros.
    local state = mage({companions = {"DyresShieldsUp", "DyresBuffReminders", "DyresDebuffTracker"}})
    local function sentences(text)
        local count = 0
        for _ in (text .. " "):gmatch("[%.%?]%s") do count = count + 1 end
        return count
    end
    local checked = 0
    local function check(text, label, allowed)
        equal(type(text), "string", label .. ": a tooltip")
        equal(text:find("\n", 1, true), nil, label .. ": one paragraph")
        equal(sentences(text) <= (allowed or 1), true, label .. ": " .. text)
        for _, word in ipairs({"combat", "Toolkit", "page", "default"}) do
            equal(text:find(word, 1, true), nil, label .. ": no \"" .. word .. "\"")
        end
        checked = checked + 1
    end
    local main = state.categories["Mage Tools Forever"]
    check(main.initializers[1].tooltip, "Conjure bar")
    check(main.initializers[2].tooltip, "Portal bar")
    for _, initializer in ipairs(state.categories.Conjure.initializers) do
        local setting = initializer.setting
        if setting and setting.variable == "MTF_CONJURE_MACROS" then
            check(initializer.tooltip, "Keep conjure macros", 2)
        elseif setting and (setting.variable == "MTF_CONJURE_SHARE_SIZE"
                or setting.variable == "MTF_CONJURE_SHIFT_TRADE" or setting.variable == CONJURE_LAYOUT
                or setting.name == "Bar size") then
            check(initializer.tooltip, setting.name)
        end
    end
    for _, initializer in ipairs(state.categories.Portals.initializers) do
        if initializer.setting and (initializer.setting.name == "Bar size"
                or initializer.setting.variable == PORTALS_LAYOUT) then
            check(initializer.tooltip, "Portals: " .. initializer.setting.name)
        end
    end
    for _, title in ipairs({"Shield display", "Reminders", "Chimes", "Procs", "Crowd Control"}) do
        for _, item in ipairs(state.categories[title].headings) do
            if item.button then check(item.tooltip, title .. ": link") end
        end
    end
    equal(checked, hasBarLayout(state) and 15 or 13, "every tooltip MTF writes")
end)
test("without Dyre's Shields Up or Dyre's Buff Reminders MTF says once what to install or enable", function()
    local function lines(state, fragment)
        local found = {}
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then found[#found + 1] = message end
        end
        return found
    end
    local state = mage()
    equal(state.mtf.available, true, "MTF works without them")
    local shield = lines(state, "Dyre's Shields Up")
    equal(#shield, 1, "said once")
    equal(shield[1], "MTF: Install Dyre's Shields Up from CurseForge for the shield display.")
    local reminders = lines(state, "Dyre's Buff Reminders")
    equal(#reminders, 1)
    equal(reminders[1], "MTF: Install Dyre's Buff Reminders from CurseForge for buff reminders, cooldown chimes, and proc arcs.")
    for _, message in ipairs(state.messages) do
        equal(message:lower():find("github", 1, true), nil, "CurseForge only")
    end
    local disabled = mage({disabledAddOns = {DyresShieldsUp = true}})
    equal(lines(disabled, "Dyre's Shields Up")[1], "MTF: Enable Dyre's Shields Up in the AddOn list for the shield display.")
    local both = mage({companions = {"DyresShieldsUp", "DyresBuffReminders"}})
    equal(#lines(both, "Dyre's Shields Up"), 0, "nothing to say with both loaded")
    equal(#lines(both, "Dyre's Buff Reminders"), 0)
    state.clear()
    state.slash("unlock")
    state.slash("lock")
    equal(#lines(state, "Install"), 0, "only at login")
end)
test("without the Settings API MTF runs and /mtf explains", function()
    local state = fixture({noSettings = true})
    equal(state.mtf.available, true)
    state.slash("")
    contains(state.last(), "settings page is unavailable")
end)

-- Dyre's Toolkit Profile (Toolkit 2.10.0; John, 2026-11-17) ------------------------

local OTHER = "Janelle - Forever"

-- Another character's saved profile, as the Toolkit keeps it.
local function otherProfile(part)
    return {snapToGrid = false, profiles = {[OTHER] = {class = "Mage", seen = 1, parts = {MageToolsForever = part},
        pending = {}}}}
end

test("profile: MTF registers its part, without the per-character keys", function()
    local state = mage({known = {[POLYMORPH] = true}})
    equal(state.mtf.profileRegistered, true)
    local found = false
    for _, addon in ipairs(state.toolkit.ProfileParts()) do
        found = found or addon == "MageToolsForever"
    end
    equal(found, true, "listed")
    local entry = state.env.DyresToolkitDB.profiles["Dyre - Forever"]
    local part = entry.parts.MageToolsForever
    equal(type(part), "table", "this character's copy is saved at registration")
    equal(part.conjure.shareSize, 10)
    for _, key in ipairs(state.mtf.PROFILE_CHARACTER_KEYS) do
        equal(part[key], nil, key .. " stays with the character")
    end
    -- A Toolkit older than 2.10.0: no part, no error, MTF works as before.
    local old = mage({noProfiles = true, known = {[POLYMORPH] = true}})
    equal(old.mtf.profileRegistered, false)
    equal(old.mtf.available, true)
    equal(old.env.MageToolsForeverConjure.shown, true, "the bars still come up")
    for _, message in ipairs(old.messages) do
        equal(message:find("error", 1, true), nil, message)
    end
end)

test("profile: sanitize turns any table into full settings and never errors", function()
    local state = mage()
    local defaults = state.mtf.SanitizeDB(nil)
    same(state.mtf.SanitizeDB({}), defaults, "{} gives the defaults")
    for _, damaged in ipairs({
        {conjure = "x", portals = 5, polymorph = true, announce = {}, locked = "no"},
        {conjure = {scale = "big", shareSize = 99.5, position = {point = 1}},
            polymorph = {width = -4, opacity = 1000, textScale = "x"}, announce = {waterWhisperText = 5}},
        {futureKey = {deep = {deeper = true}}, conjure = {enabled = false, newSetting = 3}},
    }) do
        local result = state.mtf.SanitizeDB(damaged)
        equal(type(result.conjure.scale), "number")
        equal(result.conjure.shareSize >= 1 and result.conjure.shareSize <= 20, true)
        equal(result.polymorph == nil or result.polymorph == damaged.polymorph, true, "MTF 1.5 data kept as saved")
        equal(type(result.announce.waterWhisperText), "string")
        equal(result.conjure.newSetting, nil, "unknown keys are dropped")
    end
end)

test("profile: a copy from another character changes the settings live and keeps this character's keys", function()
    local part = {
        conjure = {enabled = true, macros = true, shareSize = 5, scale = 80,
            position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 600, y = 250}},
        portals = {enabled = false, scale = 120},
        -- Another character's own keys never arrive.
        locked = false, ownedMacros = {["! Not Mine"] = true}, shield = {other = true},
        polymorph = {enabled = false, width = 999},
    }
    local state = mage({known = {[POLYMORPH] = true, [TELEPORT_STORMWIND] = true}, toolkitDB = otherProfile(part),
        db = oldPolymorphDB(true)})
    local db = state.mtf.db
    local polymorphTable, ownedBefore = db.polymorph, {}
    for name in pairs(db.ownedMacros) do ownedBefore[name] = true end
    local ok, reload = state.toolkitNS.profile:CopyFrom(OTHER)
    equal(ok, true, tostring(reload))
    equal(#reload, 0, "live, no reload")
    -- The values, in the same tables the widgets hold.
    equal(db.conjure.shareSize, 5)
    equal(db.polymorph, polymorphTable, "this character's MTF 1.5 Polymorph data, for Dyre's Debuff Tracker")
    equal(db.polymorph.width, 300)
    same(db.ownedMacros, ownedBefore, "this character's macros")
    equal(db.locked, true, "the lock is the Toolkit's")
    equal(db.shield, nil, "MTF 1.1 data stays this character's")
    -- The frames show them, with no reload.
    advance(state, 1)
    local env = state.env
    equal(env.MageToolsForeverConjure:GetScale(), 0.8, "conjure scale")
    local point = env.MageToolsForeverConjure.points[#env.MageToolsForeverConjure.points]
    equal(point[4], 600, "conjure place")
    equal(env.MageToolsForeverPortals.shown, false, "the portal bar is off")
    -- The Defaults: a clean slate, still live.
    ok, reload = state.toolkitNS.profile:CopyFrom(state.toolkit.PROFILE_DEFAULTS)
    equal(ok, true, tostring(reload))
    equal(#reload, 0)
    advance(state, 1)
    equal(db.conjure.shareSize, 10)
    equal(db.polymorph, polymorphTable, "the Defaults keep it too")
    equal(env.MageToolsForeverConjure:GetScale(), 1)
    equal(env.MageToolsForeverPortals.shown, true)
    equal(macroBody(state, "! Polymorph"), nil, "MTF writes no Polymorph macro")
end)

test("profile: export and import bring the settings back; a bad line or combat changes nothing", function()
    local state = mage({known = {[POLYMORPH] = true}})
    local db = state.mtf.db
    db.conjure.shareSize = 7
    db.announce.portalGroupText = "Hop in to %D"
    local line = state.toolkitNS.profile:Export()
    contains(line, "DYRE2:profile:")
    db.conjure.shareSize = 3
    db.announce.portalGroupText = "Changed %D"
    local ok, reload = state.toolkitNS.profile:Import(line)
    equal(ok, true, tostring(reload))
    equal(#reload, 0)
    equal(db.conjure.shareSize, 7)
    equal(db.announce.portalGroupText, "Hop in to %D")
    -- A damaged line: nothing changes.
    ok = state.toolkitNS.profile:Import(line:sub(1, -3) .. "zz")
    equal(ok, nil)
    equal(db.conjure.shareSize, 7)
    -- In combat the Toolkit refuses it; nothing changes.
    state.combat = true
    db.conjure.shareSize = 4
    ok = state.toolkitNS.profile:Import(line)
    equal(ok, nil)
    equal(db.conjure.shareSize, 4)
end)

test("profile: a damaged part from another character is repaired, never an error", function()
    local state = mage({known = {[POLYMORPH] = true}, toolkitDB = otherProfile({conjure = "broken",
        polymorph = {width = "wide", opacity = -5}, announce = 12}), db = oldPolymorphDB(true)})
    local ok, reload = state.toolkitNS.profile:CopyFrom(OTHER)
    equal(ok, true, tostring(reload))
    equal(#reload, 0)
    same(state.mtf.db.conjure, state.mtf.SanitizeDB({}).conjure, "repaired to the defaults")
    same(state.mtf.db.polymorph, oldPolymorphDB(true).polymorph, "this character's Polymorph data")
end)

local failed = 0
for index, entry in ipairs(tests) do
    local ok, message = xpcall(entry.body, debug.traceback)
    if ok then
        io.write("ok ", index, " - ", entry.name, "\n")
    else
        failed = failed + 1
        io.write("not ok ", index, " - ", entry.name, "\n", tostring(message), "\n")
    end
end
io.write(string.format("\n%d tests: %d passed, %d failed\n", #tests, #tests - failed, failed))
io.write("Mock results do not establish in-client compatibility.\n")
os.exit(failed == 0 and 0 or 1)
