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

local RUNTIME_FILES = {"Commands.lua", "Core.lua", "Layout.lua", "Conjure.lua", "Portals.lua", "Polymorph.lua", "Reminders.lua", "Shield.lua", "Chimes.lua", "Options.lua"}
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
    env.C_AddOns = {GetAddOnMetadata = function(name, field)
        equal(name, "MageToolsForever", "metadata uses the AddOn folder name")
        return state.toc[field] or ""
    end}
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
    -- As in client, setting the marker a unit already has clears it.
    env.SetRaidTarget = function(unit, index)
        local data = state.units[unit]
        local key = data.guid or data.name
        if state.marks[key] == index then index = nil end
        state.marks[key] = index
        state.markCount = (state.markCount or 0) + 1
        state.markedUnit = unit
    end
    -- State drivers: "[@unit,harm,nodead] show; hide", evaluated by the game.
    state.drivers = {}
    function state.applyDrivers()
        for frame, driver in pairs(state.drivers) do
            if driver == "[combat] hide; show" then
                frame.shown = not state.combat
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
    env.GameTooltip = {
        SetOwner = function() state.tooltip = {} end,
        SetText = function(_, text) state.tooltip[#state.tooltip + 1] = text end,
        AddLine = function(_, text) state.tooltip[#state.tooltip + 1] = text end,
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
    env.UnitGUID = function(unit) return state.units[unit] and state.units[unit].guid end
    env.UnitCanAttack = function(_, unit) return state.units[unit] ~= nil and not state.units[unit].friend end
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
    env.UnitAffectingCombat = function(unit) return unit == "player" and state.combat end
    if not options.noRestrictionAPI then
        env.Enum = env.Enum or {}
        env.Enum.AddOnRestrictionType = {Combat = 0, Encounter = 1, Chat = 5}
        env.Enum.UnitAuraSoundTrigger = {Added = 0, ApplicationsIncreased = 1, Removed = 2}
        env.C_RestrictedActions = {GetAddOnRestrictionState = function(kind)
            return (state.restrictions or {})[kind] or 0
        end}
        env.C_CombatLog = {IsCombatLogRestricted = function() return state.combatLogRestricted == true end}
        env.C_RestrictedActions.IsAddOnRestrictionActive = function(kind)
            return kind == 1 and state.encounter == true
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
        function object:EnableMouse(value) self.mouse = value == true end
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
        function object:SetSize(width, height) self.width, self.height = width, height end
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
            function button:SetMouseClickEnabled(value) self.clicks = value end
            slotOptions.initializeFrame(button)
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
        return rx + (spot[1] - 0.5) * width + point[4] * scale, ry + (spot[2] - 0.5) * height + point[5] * scale
    end
    function state.emit(event, ...)
        for _, frame in ipairs(state.frames) do
            local unit = frame.unitEvents[event]
            local first = ...
            if frame.events[event] or (unit and unit == first) then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end

    for _, name in ipairs(options.remove or {}) do env[name] = nil end
    -- Other AddOns shipping Shield.lua: {addon, version, before}; each gets its own namespace.
    state.copies = {}
    local function loadShieldCopy(spec)
        local source = assert(io.open("Shield.lua")):read("*a")
        source = source:gsub("local VERSION = %d+", "local VERSION = " .. spec.version)
        local chunk = assert(loadstring(source, "=" .. spec.addon .. "/Shield.lua"))
        setfenv(chunk, env)
        local namespace = {}
        chunk(spec.addon, namespace)
        state.copies[spec.addon] = namespace
    end
    for _, spec in ipairs(options.shieldCopies or {}) do
        if spec.before then loadShieldCopy(spec) end
    end
    state.mtf = {}
    for _, path in ipairs(options.files or RUNTIME_FILES) do
        local chunk, message = loadfile(path)
        if not chunk then error(message) end
        setfenv(chunk, env)
        chunk("MageToolsForever", state.mtf)
    end
    for _, spec in ipairs(options.shieldCopies or {}) do
        if not spec.before then loadShieldCopy(spec) end
    end
    env.MageToolsForeverDB = options.db
    state.env = env
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
    function state.clickButton(name, mouseButton)
        local button = env[name]
        local suffix = mouseButton == "RightButton" and "2" or mouseButton == "MiddleButton" and "3" or "1"
        hardware(function()
            state.used = {type = button.attributes["type" .. suffix], item = button.attributes["item" .. suffix],
                macrotext = button.attributes["macrotext" .. suffix], spell = button.attributes["spell" .. suffix]}
            -- Secure buttons run PostClick for the press and the release.
            button.scripts.PostClick(button, mouseButton, true)
            button.scripts.PostClick(button, mouseButton, false)
        end)
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
    equal(parse("debug_chimes"), "debug_chimes")
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
    state.clear()
    state.slash("debug_shield")
    contains(state.messages[1], "debug_shield UnitGetTotalAbsorbs=function")
    state.clear()
    state.slash("debug_chimes")
    contains(state.messages[1], "debug_chimes blink name=Blink")
end)
test("a missing client API disables MTF with one message naming it", function()
    local state = fixture({remove = {"InitiateTrade"}})
    equal(state.mtf.available, false)
    contains(state.last(), "This client lacks InitiateTrade")
    equal(state.categories["Mage Tools Forever"], nil, "no settings page")
end)
test("a mixed install of old and new files is reported at login", function()
    local state = fixture({files = {"Commands.lua", "Core.lua", "Layout.lua", "Conjure.lua", "Portals.lua", "Polymorph.lua", "Reminders.lua", "Shield.lua",
        "Options.lua"}})
    equal(state.mtf.available, false)
    contains(state.last(), "missing InitializeChimes")
end)

-- Saved settings ---------------------------------------------------------------

test("saved settings get defaults and are repaired on load", function()
    local state = fixture()
    local db = state.mtf.db
    equal(db.conjure.enabled, true)
    equal(db.locked, true, "every frame locked by default")
    equal(db.conjure.locked, true)
    equal(db.conjure.macros, true)
    equal(db.conjure.shareSize, 10)
    equal(db.shield.enabled, true)
    equal(db.shield.locked, true, "locked, so the ring never takes the mouse")
    equal(db.shield.number, true)
    equal(db.shield.breakSound, false)
    equal(db.chimes.enabled, true)
    equal(db.chimes.sounds.blink, "talent", "Talent ready for every spell")
    equal(db.chimes.sounds.frostnova, "talent")
    equal(db.chimes.sounds.evocation, "talent")
    equal(db.chimes.lead, 0.5)
    equal(db.chimes.spells.blink, true)
    equal(db.chimes.spells.coldsnap, false)
    local repaired = fixture({db = {conjure = {shareSize = 99, position = {point = 1}}, shield = "broken",
        chimes = {sound = "talent", sounds = {blink = "kazoo", counterspell = "alarm", frostnova = "popclick",
            iceblock = "effectmagical"}, lead = 0.7,
            spells = {blink = false}, learned = {blink = 14.9, frostnova = 5000}}}})
    db = repaired.mtf.db
    equal(db.conjure.shareSize, 20)
    equal(db.conjure.position, nil)
    equal(db.shield.enabled, true)
    equal(db.chimes.sounds.blink, "talent", "an unknown sound gives way to the default")
    equal(db.chimes.sounds.counterspell, "alarm", "a sound you chose stays")
    equal(db.chimes.sounds.frostnova, "impactspopclick", "the old Pop click key carries over")
    equal(db.chimes.sounds.iceblock, "magical", "an old effect key is mapped by Dyre's Sounds")
    equal(db.chimes.sounds.evocation, "talent", "the one sound chosen before carries over")
    equal(db.chimes.lead, 0.5)
    equal(db.chimes.spells.blink, false)
    equal(db.chimes.learned.blink, 14.9)
    equal(db.chimes.learned.frostnova, nil, "an implausible cooldown is dropped")
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
    equal(state.sent[1].message, "Here's 10 Conjured Fresh Water, conjured from pure arcane energy. "
        .. "Drink up, Lowbie Smith! Courtesy of Mage Tools Forever (MTF)")
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
    contains(state.sent[1].message, "Drink up, Runner Uppe!")
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
    equal(state.sent[1].message, "Here's 10 Conjured Fresh Water and 10 Conjured Bread, conjured from pure arcane "
        .. "energy. Eat, drink, and be merry, Lowbie Smith! Courtesy of Mage Tools Forever (MTF)")
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
    contains(macroBody(state, "! Mana Gem"), "/cast [btn:2] Conjure Mana Agate(Rank 1)")
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
        "/cast [btn:2] Conjure Water(Rank 3)",
        "/stopmacro [btn:2]",
        "/use item:8079", "/use item:8078", "/use item:8077", "/use item:3772", "/use item:2136",
        "/use item:2288", "/use item:5350"}, "\n"))
    contains(macroBody(state, "! Food"), "/cast [btn:2] Conjure Food(Rank 3)")
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
test("the conjure bar and the shield display each have a size setting", function()
    local state = mage()
    local bar, ring = state.env.MageToolsForeverConjure, state.mtf.ShieldDisplay.frame
    equal(state.mtf.db.conjure.scale, 100)
    equal(state.mtf.db.shield.scale, 100)
    state.settings.MTF_SHIELD_SCALE:SetValue(60)
    equal(ring.scale, 0.6)
    state.combat = true
    state.settings.MTF_CONJURE_SCALE:SetValue(60)
    equal(bar.scale, 1, "the bar holds secure buttons: not in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(bar.scale, 0.6)
    state.settings.MTF_SHIELD_SCALE:SetValue(999)
    equal(state.mtf.db.shield.scale, 150, "at most 150%")
    state.settings.MTF_CONJURE_SCALE:SetValue(62)
    equal(state.mtf.db.conjure.scale, 60, "in steps of 5")
    local saved = mage({db = {conjure = {scale = "huge"}, shield = {scale = 10}}})
    equal(saved.mtf.db.conjure.scale, 100)
    equal(saved.mtf.db.shield.scale, 50)
end)
test("one lock for every frame; older saved per-frame locks give way to it", function()
    local state = mage({db = {conjure = {locked = false}, shield = {locked = true}}})
    equal(state.mtf.db.locked, true)
    equal(state.mtf.db.conjure.locked, true, "the bar follows the one lock")
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

-- Shield display --------------------------------------------------------------------

local ICE_BARRIER, MANA_SHIELD = 11426, 1463

test("the shield ring shows your live absorb while a shield is up, hidden otherwise", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    equal(ring.shown, false)
    equal(ring.mouse, false, "never blocks world clicks")
    state.cast(ICE_BARRIER)
    equal(ring.shown, true)
    equal(ring.bar.value, state.absorb, "the secret absorb, passed on unread")
    equal(ring.bar.maxValue, state.absorb, "measured against the shield's size as it landed")
    equal(ring.text.text.abbreviated, state.absorb)
    equal(ring.visible.alpha, state.absorb, "the ring's opacity is the absorb, so it drops at zero")
    equal(ring.bar.barColor[3], 1, "Ice Barrier blue")
    state.now = state.now + 61
    state.runTimers()
    equal(ring.shown, false, "hidden when the shield ends")
end)
test("out of combat a broken shield hides at once; in combat buffs are not read", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    state.cast(MANA_SHIELD)
    state.combat = true
    state.emit("UNIT_AURA", "player")
    equal(ring.shown, true, "in combat MTF cannot see the buff")
    state.combat = false
    state.emit("UNIT_AURA", "player")
    equal(ring.shown, false)
end)
test("Mana Shield after a ward leaves the outer crescent in the ward's color", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    state.cast(543)
    equal(ring.bar.barColor[1], 1, "Fire Ward orange")
    state.cast(MANA_SHIELD)
    equal(ring.bar.barColor[1], 1, "still orange: Mana Shield has the inner crescent")
    equal(ring.bar.barColor[3], 0.15)
    local alone = mage()
    alone.cast(MANA_SHIELD)
    equal(alone.mtf.ShieldDisplay.frame.shown, true, "Mana Shield alone keeps the display up")
end)
test("a shield still up after a reload shows again", function()
    local state = mage()
    state.buffs = {["Ice Barrier"] = {name = "Ice Barrier", expirationTime = state.now + 40}}
    state.emit("PLAYER_ENTERING_WORLD")
    equal(state.mtf.ShieldDisplay.frame.shown, true)
end)
test("unlocked, the ring shows a sample and can be dragged", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    state.settings.MTF_UNLOCKED:SetValue(true)
    equal(ring.shown, true)
    equal(ring.mouse, true)
    equal(ring.bar.value, 1, "the sample shows full")
    equal(ring.text.text, "drag me")
    equal(ring.sample.shown, true, "a sample inner crescent and icons too")
    contains(ring.sample.children[1].texture, "ShieldArcInner")
    equal(ring.visible.alpha, 1, "the sample shows in full")
    ring.scripts.OnDragStart(ring)
    equal(ring.moving, true)
    ring:SetPoint("LEFT", state.env.UIParent, "LEFT", 10, 0)
    ring.scripts.OnDragStop(ring)
    equal(state.mtf.db.shield.position.point, "LEFT")
    state.settings.MTF_UNLOCKED:SetValue(false)
    equal(ring.sample.shown, false)
    equal(ring.shown, false)
    equal(ring.mouse, false)
end)
test("/mtf unlock and /mtf lock move the shield display and the conjure bar together", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    state.slash("unlock")
    equal(state.mtf.db.shield.locked, false)
    equal(state.mtf.db.conjure.locked, false)
    equal(state.env.MageToolsForeverConjure.mover.shown, true, "the bar is outlined too")
    equal(state.settings.MTF_UNLOCKED:GetValue(), true, "the main page's switch follows")
    equal(ring.shown, true, "a sample to drag")
    equal(ring.mouse, true)
    equal(ring.mover.shown, true, "outlined, with a hint")
    contains(ring.mover.hint.text, "/mtf lock when done")
    contains(state.last(), "drag them where you want")
    state.slash("lock")
    equal(state.mtf.db.shield.locked, true)
    equal(state.mtf.db.conjure.locked, true)
    equal(state.env.MageToolsForeverConjure.mover.shown, false)
    equal(state.settings.MTF_UNLOCKED:GetValue(), false)
    equal(ring.shown, false)
    equal(ring.mouse, false)
    equal(ring.mover.shown, false)
end)
test("the absorb number can be hidden, and the break sound turned on", function()
    local state = mage()
    state.settings.MTF_SHIELD_NUMBER:SetValue(false)
    state.cast(ICE_BARRIER)
    equal(state.mtf.ShieldDisplay.frame.text.text, "")
    equal(state.auraSoundCount, nil)
    state.settings.MTF_SHIELD_BREAK_SOUND:SetValue(true)
    equal(state.auraSoundCount, 33, "every rank of the six shields a Mage can get")
    equal(state.auraSounds[1].trigger, 2, "on removal")
    equal(state.auraSounds[1].info.spellID, ICE_BARRIER)
    equal(state.auraSounds[1].info.soundFileName,
        "Interface\\AddOns\\DyresSounds\\Sounds\\FadingSlowDisappear.mp3", "Dyre's Sounds' file: MTF ships none")
    equal(state.sounds[#state.sounds].key, "fadingslow", "turning it on plays it once")
    state.settings.MTF_SHIELD_BREAK_SOUND_CHOICE:SetValue("cartoonvanish")
    equal(state.sounds[#state.sounds].key, "cartoonvanish", "choosing plays it")
    equal(state.mtf.db.shield.breakSoundKey, "cartoonvanish")
    local live
    for _, sound in pairs(state.auraSounds) do live = sound end
    equal(live.info.soundFileName, "Interface\\AddOns\\DyresSounds\\Sounds\\CartoonVanish.mp3",
        "registered again with the new sound")
    state.settings.MTF_SHIELD_BREAK_SOUND:SetValue(false)
    local left = 0
    for _ in pairs(state.auraSounds) do left = left + 1 end
    equal(left, 0)
end)
test("the break sound keeps the player's choice, and without Dyre's Sounds MTF says once what to install", function()
    equal(mage({db = {shield = {breakSoundKey = "cartoonvanish"}}}).mtf.db.shield.breakSoundKey, "cartoonvanish",
        "a choice saved by 0.2 is a Dyre's Sounds key")
    local state = mage({noSounds = true, db = {shield = {breakSoundKey = "magical"}}})
    equal(state.mtf.db.shield.breakSoundKey, "magical", "a missing library never resets a choice")
    local page = state.categories.Shield
    local dropdown
    for _, initializer in ipairs(page.initializers) do
        if initializer.setting.variable == "MTF_SHIELD_BREAK_SOUND_CHOICE" then dropdown = initializer end
    end
    equal(#dropdown.choices(), 0, "nothing to choose from")
    equal(dropdown.soundMenu, nil)
    state.settings.MTF_SHIELD_BREAK_SOUND:SetValue(true)
    equal(state.auraSoundCount, nil, "no sound to register")
    state.settings.MTF_SHIELD_NUMBER:SetValue(false)
    local count, said = 0, nil
    for _, message in ipairs(state.messages) do
        if message:find("Install Dyre's Sounds", 1, true) then count, said = count + 1, message end
    end
    equal(count, 1, "one line for all of MTF's sounds, the shield sound included")
    contains(said, "the chimes and the shield sound")
end)
test("an absorb MTF cannot name, from another player or a trinket, shows for 30 seconds", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    state.emit("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    equal(ring.shown, true)
    equal(ring.bar.barColor[2], 0.85, "the neutral color")
    state.now = state.now + 31
    state.runTimers()
    equal(ring.shown, false)
end)
test("a tiny absorb stays hidden: a gate bar ending at the minimum clips the ring", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    state.emit("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    equal(ring.gate.value, state.absorb, "the secret absorb, passed on unread")
    equal(ring.gate.minValue, 74, "one point wide, so the fill is empty or full")
    equal(ring.gate.maxValue, 75, "5% of 1500 health beats 25 points")
    equal(ring.gated.clips, true)
    equal(ring.gated.points[2][2], ring.gate:GetStatusBarTexture(), "the clip ends where the gate's fill ends")
    equal(ring.bar.parent, ring.gated)
    equal(ring.gated.parent, ring.visible, "the opacity still follows the absorb")
    state.slash("unlock")
    equal(ring.gate.value, 1, "unlocked, the gate is open for the sample")
end)
test("a known shield going is not mistaken for another absorb", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    state.cast(ICE_BARRIER)
    state.now = state.now + 10
    state.emit("UNIT_AURA", "player")
    equal(ring.shown, false, "broke early, seen out of combat")
    state.emit("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    equal(ring.shown, false)
end)
test("a Priest's Power Word: Shield on you shows in its own color", function()
    local state = mage()
    state.env.C_Spell.GetSpellName = function(id)
        if id == 17 then return "Power Word: Shield" end
        return SPELLS[id]
    end
    state.buffs = {["Power Word: Shield"] = {name = "Power Word: Shield", expirationTime = state.now + 25}}
    state.emit("UNIT_AURA", "player")
    local ring = state.mtf.ShieldDisplay.frame
    equal(ring.shown, true)
    equal(ring.bar.barColor[3], 0.85, "Power Word: Shield white")
end)
test("several AddOns shipping the shield display show only one ring", function()
    local state = mage({shieldCopies = {{addon = "ShieldForever", version = 1}}})
    equal(state.mtf.ShieldDisplay.IsOwner(), true, "first registered wins a tie")
    local other = state.copies.ShieldForever.ShieldDisplay
    local said = {}
    other.Initialize({settings = function() return other.Sanitize({}) end,
        report = function(message) said[#said + 1] = message end})
    equal(other.frame, nil, "the other copy draws nothing")
    contains(said[1], "shown by MageToolsForever")
    state.clear()
    state.slash("debug_shield")
    contains(table.concat(state.messages, "|"), "owner=MageToolsForever copies=MageToolsForever v8 (running), ShieldForever v1 (running)")
    contains(table.concat(state.messages, "|"), "minimumAbsorb=75")
    local text = table.concat(state.messages, "|")
    contains(text, "the absorb total shows above your character")
    equal(text:find("failed", 1, true), nil, "every debug step ran")
end)
test("with Dyre's Shields Up loaded, MTF draws no shield and greys out its shield settings", function()
    local state = mage({loadedAddOns = {DyresShieldsUp = true}, db = {shield = {scale = 80, breakSound = true}}})
    equal(state.mtf.ShieldDisplay.frame, nil, "no ring of its own: Dyre's Shields Up draws it")
    equal(state.mtf.ShieldDisplay.IsOwner(), false, "not even a candidate")
    state.cast(ICE_BARRIER)
    state.slash("unlock")
    state.slash("lock")
    for _, message in ipairs(state.messages) do
        equal(message:find("shown by", 1, true), nil, "no election message")
    end
    equal(state.mtf.db.shield.scale, 80, "its saved shield settings stay as they are")
    equal(state.mtf.db.shield.breakSound, true)
    local seen = 0
    for _, page in pairs(state.categories) do
        for _, initializer in ipairs(page.initializers) do
            local variable = initializer.setting and initializer.setting.variable or ""
            if variable:find("^MTF_SHIELD_") then
                seen = seen + 1
                equal(initializer.modifyPredicates[1](), false, variable .. " is greyed out")
                contains(initializer.tooltip, "Dyre's Shields Up shows the shield display now")
            end
        end
    end
    equal(seen, 5, "the switch, number, sound, its choice, and the size")
    equal(state.categories.Shield, nil, "the list name says who runs it")
    local page = state.categories["Shield (Dyre's Shields Up)"]
    equal(page.headings[1].heading, "Shields are now managed by Dyre's Shields Up")
    contains(page.headings[1].tooltip, "/dsu")
    equal(#mage().categories.Shield.headings, 0, "no heading without Dyre's Shields Up")
end)
test("a newer shield display in another AddOn takes over once its AddOn runs it", function()
    local state = mage({shieldCopies = {{addon = "ShieldForever", version = 9}}})
    equal(state.mtf.ShieldDisplay.frame ~= nil, true, "a copy whose AddOn never runs it does not count")
    local function shieldGreyed(want)
        local seen = 0
        for _, page in pairs(state.categories) do
            for _, initializer in ipairs(page.initializers) do
                local variable = initializer.setting and initializer.setting.variable or ""
                if variable:find("^MTF_SHIELD_") then
                    seen = seen + 1
                    equal(initializer.modifyPredicates[1](), not want, variable .. (want and " is greyed out" or " is not greyed"))
                end
            end
        end
        equal(seen, 5, "the switch, number, sound, its choice, and the size")
    end
    shieldGreyed(false)
    local other = state.copies.ShieldForever.ShieldDisplay
    other.Initialize({settings = function() return other.Sanitize({}) end, report = function() end})
    equal(state.mtf.ShieldDisplay.IsOwner(), false)
    shieldGreyed(true)
    equal(state.mtf.ShieldDisplay.frame, nil, "MTF stood down")
    local found = false
    for _, message in ipairs(state.messages) do
        if message:find("The shield display is shown by ShieldForever", 1, true) then found = true end
    end
    equal(found, true)
    state.cast(ICE_BARRIER)
    state.slash("reset")
end)
test("an icon per shield, shown by Blizzard's aura display, each in its own spot", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    local container = ring.icons
    equal(container.unit, "player")
    equal(#container.slots, 6, "one slot per shield a Mage can get, Blessing of Protection included")
    equal(container.slots[1].key, "icebarrier")
    equal(container.slots[1].filter, "HELPFUL")
    equal(container.slots[1].ids[13033], true, "a set of every Ice Barrier rank, as the container requires")
    equal(container.slots[1].ids[4], nil, "not a list")
    -- The engine's shown state is secret, so each icon is placed once, in its spot.
    local barrier, ward, frost = ring.iconButtons.icebarrier, ring.iconButtons.fireward, ring.iconButtons.frostward
    equal(barrier.points[1][4], -61.5, "first of six spots (123 px wide), centered under the number")
    equal(ward.points[1][4] - barrier.points[1][4], 42, "Mana Shield's spot between them")
    equal(frost.points[1][4] - ward.points[1][4], 21)
    equal(ring.iconButtons.powerwordshield.points[1][4] - frost.points[1][4], 21,
        "Power Word: Shield in the last spot")
    equal(ring.iconButtons.sacrifice, nil, "no Warlock shields on a Mage")
end)
test("Mana Shield drains with time in the inner crescent; absorb shields stay in the outer one", function()
    local state = mage()
    local ring = state.mtf.ShieldDisplay.frame
    local mana = ring.iconButtons.manashield
    equal(mana.mouse, false, "never blocks clicks on the world")
    local bar = mana.display.bar
    equal(bar, ring.timedBars.manashield)
    equal(mana.display.barOptions.direction, 1, "drains with the time left")
    contains(bar.statusBarTexture, "ShieldArcInner")
    equal(bar.points[1][5], -21.25, "the bar spans the crescent itself, so it empties as the buff ends")
    equal(bar.points[2][5], 21.25)
    equal(bar.points[1][2], ring, "centered on the ring")
    equal(ring.bar.points[1][5], -6.25, "the outer bar too")
    equal(ring.bar.points[1][2], ring, "the ring, not its taller clipping frame")
    equal(bar.barColor[1], 0.68, "Mana Shield purple")
    equal(ring.iconButtons.fireward.display.bar, nil, "an absorb shield is not timed")
    equal(ring.bar.statusBarTexture:find("Inner"), nil, "the outer crescent is the absorb total")
end)
test("without the absorb API the shield display stays off with one message", function()
    local state = mage({remove = {"UnitGetTotalAbsorbs"}})
    equal(state.mtf.available, true)
    equal(state.mtf.ShieldDisplay.frame, nil)
    local found = false
    for _, message in ipairs(state.messages) do
        if message:find("The shield display stays off", 1, true) then found = true end
    end
    equal(found, true)
end)

-- Cooldown chimes ----------------------------------------------------------------

local BLINK, FROST_NOVA, COLD_SNAP = 1953, 122, 12472

local function advance(state, seconds)
    state.now = state.now + seconds
    state.runTimers()
end

test("out of combat, MTF reads the real cooldown and chimes just before it ends", function()
    local state = mage()
    state.cooldowns[BLINK] = {start = state.now, duration = 15}
    state.cast(BLINK)
    advance(state, 0.1)
    equal(state.mtf.db.chimes.learned.blink, 15)
    advance(state, 14.2)
    equal(#state.sounds, 0)
    advance(state, 0.3)
    equal(#state.sounds, 1, "half a second early")
    equal(state.sounds[1].key, "talent", "Talent ready, played by Dyre's Sounds")
    advance(state, 5)
    equal(#state.sounds, 1, "once")
end)
test("a chime plays its own sound through Dyre's Sounds, also in combat", function()
    local state = mage()
    state.settings.MTF_CHIME_SOUND_BLINK:SetValue("effectmagical")
    equal(state.mtf.db.chimes.sounds.blink, "magical", "saved in Dyre's Sounds' spelling")
    equal(state.sounds[1].key, "magical", "previewed")
    equal(state.sounds[1].speech, "Blink ready", "the speech text goes along")
    state.combat = true
    state.cast(BLINK)
    advance(state, 15)
    equal(#state.sounds, 2)
    equal(state.sounds[2].key, "magical", "the chime plays it, also in combat")
    equal(state.played, nil, "MTF plays no file of its own")
end)
test("one cast chimes once, even when the client reports it twice", function()
    local state = mage()
    state.cooldowns[FROST_NOVA] = {start = state.now, duration = 25}
    state.cast(FROST_NOVA)
    state.cast(865)
    advance(state, 0.1)
    advance(state, 30)
    equal(#state.sounds, 1)
    state.clear()
    state.slash("debug_chimes")
    local text = table.concat(state.messages, "|")
    contains(text, "cast frostnova spell=122")
    contains(text, "cast frostnova spell=865")
    contains(text, "played frostnova")
end)
test("in combat the cooldown is secret, so MTF uses the length it learned", function()
    local state = mage({db = {chimes = {learned = {blink = 13}}}})
    state.combat = true
    state.cooldowns[BLINK] = {start = state.now, duration = 15}
    state.cast(BLINK)
    advance(state, 12.4)
    equal(#state.sounds, 0)
    advance(state, 0.2)
    equal(#state.sounds, 1)
end)
test("without a learned length, Classic's is used", function()
    local state = mage()
    state.combat = true
    state.cast(FROST_NOVA)
    advance(state, 24.4)
    equal(#state.sounds, 0)
    advance(state, 0.2)
    equal(#state.sounds, 1)
end)
test("Cold Snap cancels Frost chimes; switches and the lead are honored", function()
    local state = mage()
    state.cast(FROST_NOVA)
    state.cast(COLD_SNAP)
    advance(state, 30)
    equal(#state.sounds, 0, "Frost Nova is ready already; Cold Snap is off by default")
    state.settings.MTF_CHIMES_LEAD:SetValue(0)
    state.cast(BLINK)
    advance(state, 14.9)
    equal(#state.sounds, 0)
    advance(state, 0.2)
    equal(#state.sounds, 1)
    state.settings.MTF_CHIME_BLINK:SetValue(false)
    state.cast(BLINK)
    advance(state, 20)
    equal(#state.sounds, 1, "Blink switched off")
    state.settings.MTF_CHIME_BLINK:SetValue(true)
    state.settings.MTF_CHIMES_ENABLED:SetValue(false)
    state.cast(BLINK)
    advance(state, 20)
    equal(#state.sounds, 1, "chimes off")
    state.settings.MTF_CHIMES_ENABLED:SetValue(true)
    state.cast(FIREBALL)
    advance(state, 20)
    equal(#state.sounds, 1, "other spells never chime")
end)

local function soundDropdown(state, key)
    local soundSetting = state.settings["MTF_CHIME_SOUND_" .. key:upper()]
    for _, initializer in ipairs(state.categories["Cooldown Chimes"].initializers) do
        if initializer.setting == soundSetting then return initializer, soundSetting end
    end
end

test("each chime's sound is chosen in Dyre's Sounds' menu under its switch", function()
    local state = mage()
    local dropdown = soundDropdown(state, "blink")
    equal(dropdown.parentInitializer.setting, state.settings.MTF_CHIME_BLINK, "under Blink's switch")
    equal(dropdown.soundMenu, "all", "Dyre's Sounds' nested menu, every kind of sound")
    local labels = {}
    for _, choice in ipairs(dropdown.choices()) do labels[#labels + 1] = choice.label end
    equal(table.concat(labels, ","), "Dyre's Picks: Fading slow disappear,Dyre's Picks: Cartoon vanish,"
        .. "Dyre's Picks: Magical disappear,Interface: Talent ready,Interface: Alarm clock,Short: Bell Strike,"
        .. "Impacts: Pop Click,Imp: Spell chirp,Text to Speech", "the plain list is the library's")
    contains(dropdown.tooltip, "Text to Speech says \"Blink ready\"")
    state.settings.MTF_CHIME_SOUND_BLINK:SetValue("shortbellstrike")
    equal(state.mtf.db.chimes.sounds.blink, "shortbellstrike")
    equal(state.sounds[#state.sounds].key, "shortbellstrike", "choosing one plays it")
    local count = #state.sounds
    state.settings.MTF_CHIME_SOUND_BLINK:SetValue("kazoo")
    equal(state.mtf.db.chimes.sounds.blink, "shortbellstrike", "a sound the library lacks is ignored")
    equal(#state.sounds, count)
    equal(state.mtf.db.chimes.sounds.frostnova, "talent", "Frost Nova keeps its own")
end)
test("Text to Speech says the spell, and without a voice the default plays", function()
    local state = mage()
    state.voice = true
    state.settings.MTF_CHIME_SOUND_BLINK:SetValue("voice")
    equal(state.sounds[1].key, "voice")
    equal(state.sounds[1].speech, "Blink ready")
    state.cast(BLINK)
    advance(state, 15)
    equal(state.sounds[2].key, "voice")
    equal(state.sounds[2].speech, "Blink ready", "said when it is ready")
    state.voice = false
    state.cast(BLINK)
    advance(state, 15)
    equal(state.sounds[3].key, "talent", "no voice: the default sound instead")
    state.settings.MTF_CHIME_SOUND_FROSTNOVA:SetValue("popclick")
    equal(state.mtf.db.chimes.sounds.frostnova, "impactspopclick", "an old key, mapped")
    state.clear()
    state.slash("debug_chimes")
    contains(state.messages[1], "debug_chimes blink name=Blink known=")
    contains(state.messages[1], "sound=voice")
    contains(table.concat(state.messages, "|"), "sounds=ok playedBy=MTF lead=0.5")
end)
test("without Dyre's Sounds chimes are timed, nothing plays, and MTF says so once", function()
    local state = mage({noSounds = true, db = {chimes = {sounds = {blink = "effectmagical", frostnova = "nonsense"}}}})
    local function count()
        local found = 0
        for _, message in ipairs(state.messages) do
            if message:find("Install Dyre's Sounds to hear MTF's sounds", 1, true) then found = found + 1 end
        end
        return found
    end
    equal(count(), 1, "said at login")
    local said
    for _, message in ipairs(state.messages) do
        if message:find("Install Dyre's Sounds", 1, true) then said = message end
    end
    contains(said, "MTF: ")
    contains(said, "Get it from CurseForge.", "says where to get it")
    equal(said:find("github", 1, true), nil, "CurseForge only, for now")
    equal(state.mtf.db.chimes.sounds.blink, "effectmagical", "a saved choice is kept for when it is installed")
    equal(state.mtf.db.chimes.sounds.frostnova, "nonsense", "nothing is reset without the library")
    state.combat = true
    state.cast(BLINK)
    advance(state, 20)
    equal(#state.sounds, 0)
    equal(state.played, nil)
    state.mtf.PreviewChime("blink")
    equal(count(), 1, "once per session")
    equal(state.settings.MTF_CHIME_SOUND_BLINK, nil, "no sound menus to fill")
    contains(state.categories["Cooldown Chimes"].initializers[2].tooltip, "Install Dyre's Sounds")
    state.clear()
    state.slash("debug_chimes")
    contains(table.concat(state.messages, "|"), "sounds=missing")
end)
test("with an older Dyre's Sounds MTF says to update it", function()
    local state = mage({oldSounds = true})
    local found
    for _, message in ipairs(state.messages) do
        if message:find("Update Dyre's Sounds", 1, true) then found = message end
    end
    contains(found, "too old")
    state.cast(BLINK)
    advance(state, 20)
    equal(#state.sounds, 0)
end)
local function chimesStandAside(addon, title, slash)
    local saved = {enabled = true, lead = 1, spells = {blink = true, coldsnap = true},
        sounds = {blink = "shortbellstrike"}, learned = {blink = 14}}
    local state = mage({loadedAddOns = {[addon] = true}, db = {chimes = saved}})
    state.cast(BLINK)
    advance(state, 20)
    state.mtf.PreviewChime("blink")
    equal(#state.sounds, 0, title .. " plays them")
    local chimes = state.mtf.db.chimes
    equal(chimes.lead, 1)
    equal(chimes.spells.coldsnap, true)
    equal(chimes.sounds.blink, "shortbellstrike")
    equal(chimes.learned.blink, 14, "left for " .. title .. " to copy")
    equal(state.categories["Cooldown Chimes"], nil, "the list name says who runs them")
    local page = state.categories["Cooldown Chimes (" .. title .. ")"]
    equal(page.headings[1].heading, "Cooldown chimes are now managed by " .. title)
    contains(page.headings[1].tooltip, "Use " .. slash .. " to change them.")
    contains(page.headings[1].tooltip, "if you remove " .. title .. ".")
    for _, initializer in ipairs(page.initializers) do
        equal(initializer.modifyPredicates[1](), false, initializer.setting.variable .. " is greyed out")
    end
    contains(page.initializers[1].tooltip, title .. " is installed and plays the chimes")
    contains(page.initializers[1].tooltip, "(" .. slash .. ")")
    contains(page.initializers[2].tooltip, title)
    local found
    for _, initializer in ipairs(state.categories["Mage Tools Forever"].initializers) do
        if initializer.setting.variable == "MTF_CHIMES_ENABLED" then
            found = initializer
        end
    end
    contains(found.tooltip, title .. " is installed and plays the chimes")
    equal(found.modifyPredicates[1](), false, "the main page's chimes switch is greyed out")
    state.clear()
    state.slash("debug_chimes")
    contains(table.concat(state.messages, "|"), "playedBy=" .. addon)
    local quiet = mage({noSounds = true, loadedAddOns = {[addon] = true}})
    for _, message in ipairs(quiet.messages) do
        equal(message:find("Install Dyre's Sounds", 1, true), nil, "no install message for chimes " .. title .. " plays")
    end
end
test("with Dyre's Buff Reminders loaded MTF plays no chimes and keeps its settings", function()
    chimesStandAside("DyresBuffReminders", "Dyre's Buff Reminders", "/dbr")
end)
test("with Dyre's Cooldown Chimes loaded MTF plays no chimes and keeps its settings", function()
    chimesStandAside("DyresCooldownChimes", "Dyre's Cooldown Chimes", "/dcc")
end)
test("with both loaded Dyre's Buff Reminders is named for the chimes", function()
    local state = mage({loadedAddOns = {DyresBuffReminders = true, DyresCooldownChimes = true}})
    state.cast(BLINK)
    advance(state, 20)
    equal(#state.sounds, 0)
    equal(state.mtf.ChimesOwner().addon, "DyresBuffReminders")
    local page = state.categories["Cooldown Chimes (Dyre's Buff Reminders)"]
    contains(page.headings[1].tooltip, "/dbr")
end)

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
    equal(state.sent[1].message, "A portal to Ironforge shimmers open! Step through before it fades. "
        .. "- via Mage Tools Forever (MTF)")
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
    equal(state.sent[1].message, "summons powerful arcane energies to whisk themselves away to Ironforge. "
        .. "- via Mage Tools Forever (MTF)")
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
    equal(table.concat(names, ","), "waterWhisper,foodWhisper,bothWhisper,portalGroup,polymorphGroup,teleportEmote")
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

-- Polymorph ---------------------------------------------------------------------------

local POLYMORPH = 118

local function sheepTarget(state, name, guid)
    state.units.target = {name = name or "Defias Pillager", guid = guid or "mob-1", level = 20}
end

local function castPolymorph(state, spellID)
    spellID = spellID or POLYMORPH
    local target = state.units.target and state.units.target.name or ""
    state.emit("UNIT_SPELLCAST_SENT", "player", target, "cast-" .. spellID, spellID)
    state.cast(spellID)
end

test("Polymorph tells the group as the cast starts, never when alone", function()
    local state = mage({known = {[POLYMORPH] = true}})
    sheepTarget(state)
    castPolymorph(state)
    equal(#state.sent, 0, "alone")
    state.group = "party"
    advance(state, 4)
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-2", POLYMORPH)
    equal(#state.sent, 1, "at the start of the cast")
    equal(state.sent[1].chatType, "PARTY")
    equal(state.sent[1].message, "Sheeping Defias Pillager; you spank it, you tank it")
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-3", POLYMORPH)
    equal(#state.sent, 1, "a quick recast is not repeated")
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-4", FIREBALL)
    equal(#state.sent, 1, "only Polymorph")
    advance(state, 4)
    state.mtf.db.announce.polymorphGroup = false
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-5", POLYMORPH)
    equal(#state.sent, 1, "its switch turns it off")
end)
test("a landed Polymorph marks the mob with the moon and shows the bar on its unit", function()
    local state = mage({known = {[POLYMORPH] = true}})
    local bar = state.env.MageToolsForeverPolymorphBar
    equal(bar.shown, false, "nothing sheeped")
    sheepTarget(state)
    castPolymorph(state)
    equal(state.marks["mob-1"], 5, "the moon")
    equal(bar.shown, true)
    equal(bar.name.text, "Defias Pillager")
    equal(bar.container.unit, "target")
    equal(bar.container.slots[1].ids[POLYMORPH], true)
    equal(bar.container.slots[1].filter, "HARMFUL|PLAYER")
    castPolymorph(state)
    equal(state.markCount, 1, "an existing moon is left alone, not toggled off")
    -- Tabbing away: the bar follows the mob's nameplate.
    state.units.nameplate3 = state.units.target
    state.units.target = {name = "Defias Bandit", guid = "mob-2", level = 20}
    state.emit("PLAYER_TARGET_CHANGED")
    equal(bar.container.unit, "nameplate3")
    state.units.nameplate3.dead = true
    state.emit("UNIT_HEALTH", "nameplate3")
    equal(bar.shown, false, "gone when the mob dies")
end)
test("a Polymorph cast on the mob under the mouse is tracked and marked", function()
    local state = mage({known = {[POLYMORPH] = true}})
    state.units.mouseover = {name = "Defias Pillager", guid = "mob-7", level = 20}
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-m", POLYMORPH)
    state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-m", POLYMORPH)
    local bar = state.env.MageToolsForeverPolymorphBar
    equal(bar.shown, true, "tracked")
    equal(bar.name.text, "Defias Pillager")
    equal(state.marks["mob-7"], 5, "the moon, through mouseover")
    equal(bar.container.unit, "none", "the bar never binds to mouseover")
    state.units.nameplate5 = state.units.mouseover
    state.units.mouseover = nil
    state.emit("NAME_PLATE_UNIT_ADDED", "nameplate5")
    equal(bar.container.unit, "nameplate5", "it finds the mob on its nameplate")
end)
test("a Polymorph that lands in combat still gets the moon, on your target", function()
    local state = mage({known = {[POLYMORPH] = true}})
    sheepTarget(state)
    state.units.nameplate2 = state.units.target
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-c", POLYMORPH)
    state.combat = true
    state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-c", POLYMORPH)
    equal(state.marks["mob-1"], 5, "marked although the marker cannot be read in combat")
    equal(state.markedUnit, "target", "your target, as TankHelper marks")
    -- A recast in combat on the same mob must not toggle the moon off.
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-d", POLYMORPH)
    state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-d", POLYMORPH)
    equal(state.marks["mob-1"], 5, "still the moon after a recast")
    equal(state.markCount, 1, "marked once")
    state.clear()
    state.combat = false
    state.slash("debug_polymorph")
    contains(table.concat(state.messages, "|"), "marked=target (marker unreadable)")
end)
test("the mark switch and the bar's switch are respected", function()
    local state = mage({known = {[POLYMORPH] = true}})
    state.settings.MTF_POLYMORPH_MARK:SetValue(false)
    sheepTarget(state)
    castPolymorph(state)
    equal(state.marks["mob-1"], nil)
    equal(state.env.MageToolsForeverPolymorphBar.shown, true)
    state.settings.MTF_POLYMORPH_ENABLED:SetValue(false)
    equal(state.env.MageToolsForeverPolymorphBar.shown, false)
    equal(state.env.MageToolsForeverPolymorph.shown, false, "no click area either")
end)
test("the bar forgets the mob once the longest Polymorph is over", function()
    local state = mage({known = {[POLYMORPH] = true}})
    sheepTarget(state)
    castPolymorph(state)
    advance(state, 54)
    equal(state.env.MageToolsForeverPolymorphBar.shown, true)
    advance(state, 2)
    equal(state.env.MageToolsForeverPolymorphBar.shown, false)
end)
test("clicking the bar re-sheeps the mob by name and goes back to your target", function()
    local state = mage({known = {[POLYMORPH] = true}})
    local holder = state.env.MageToolsForeverPolymorph
    equal(holder.protected, true, "a secure button")
    equal(holder.attributes.type1, nil, "nothing to re-sheep yet")
    sheepTarget(state)
    castPolymorph(state)
    equal(holder.attributes.type1, "macro")
    equal(holder.attributes.macrotext1, "/cast [@focus,harm,nodead] Polymorph\n/stopmacro [@focus,exists]"
        .. "\n/cleartarget\n/targetexact Defias Pillager\n/cast [@target,harm,nodead] Polymorph\n/targetlasttarget")
    -- In combat the click cannot change; it follows after combat.
    state.combat = true
    sheepTarget(state, "Defias Bandit", "mob-2")
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Bandit", "cast-28272", 28272)
    state.cast(28272)
    equal(state.env.MageToolsForeverPolymorphBar.name.text, "Defias Bandit  |cff999999(click: Defias Pillager)|r",
        "the bar shows in combat, and says whom its click still sheeps")
    contains(holder.attributes.macrotext1, "Defias Pillager")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(holder.attributes.macrotext1, "/cast [@focus,harm,nodead] Polymorph: Pig\n/stopmacro [@focus,exists]"
        .. "\n/cleartarget\n/targetexact Defias Bandit\n/cast [@target,harm,nodead] Polymorph: Pig\n/targetlasttarget", "the same Polymorph you cast")
end)
test("a Polymorph begun before combat sets the click before it lands in combat", function()
    local state = mage({known = {[POLYMORPH] = true}})
    local holder = state.env.MageToolsForeverPolymorph
    sheepTarget(state)
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-118", POLYMORPH)
    state.combat = true
    state.cast(POLYMORPH)
    equal(holder.attributes.macrotext1, "/cast [@focus,harm,nodead] Polymorph\n/stopmacro [@focus,exists]"
        .. "\n/cleartarget\n/targetexact Defias Pillager\n/cast [@target,harm,nodead] Polymorph\n/targetlasttarget", "ready for the whole fight")
    equal(state.env.MageToolsForeverPolymorphBar.shown, true)
end)
test("the click is there when the client knows Polymorph by its own spell ID", function()
    local state = mage({spellbook = {{spellID = 900118, name = "Polymorph"}}, known = {[900118] = true}})
    equal(state.env.MageToolsForeverPolymorph.shown, true, "known by its spellbook ID")
    state.clear()
    state.slash("debug_polymorph")
    contains(state.messages[1], "known=true")
end)
test("a recast from the bar that lands in combat leaves the click working", function()
    -- In client: the first click recast fine, and every click after failed,
    -- because the landing recast rescaled the secure holder in combat.
    local state = mage({known = {[POLYMORPH] = true}})
    local holder = state.env.MageToolsForeverPolymorph
    sheepTarget(state)
    castPolymorph(state)
    local macro = holder.attributes.macrotext1
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "cast-again", POLYMORPH)
    state.combat = true
    state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-again", POLYMORPH)
    state.emit("PLAYER_TARGET_CHANGED")
    state.settings.MTF_POLYMORPH_SCALE:SetValue(80)
    equal(holder.attributes.macrotext1, macro, "the click still sheeps the mob")
    equal(holder.scale, 1, "nothing secure changed in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(holder.scale, 0.8, "the size applies after combat")
    equal(state.env.MageToolsForeverPolymorphBar.scale, 0.8, "the bar with it")
end)
test("a Polymorph that fails out of combat gives the click back to the sheep that is up", function()
    local state = mage({known = {[POLYMORPH] = true}})
    local holder = state.env.MageToolsForeverPolymorph
    sheepTarget(state)
    castPolymorph(state)
    sheepTarget(state, "Defias Bandit", "mob-2")
    state.emit("UNIT_SPELLCAST_SENT", "player", "Defias Bandit", "cast-fail", POLYMORPH)
    contains(holder.attributes.macrotext1, "Defias Bandit", "set as the cast starts")
    state.emit("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-fail", POLYMORPH)
    contains(holder.attributes.macrotext1, "Defias Pillager", "back to the sheep that is up")
end)
test("\"! Polymorph\" focuses the mob and sheeps your focus, once you know Polymorph", function()
    local state = mage()
    equal(macroBody(state, "! Polymorph"), nil, "not before you learn Polymorph")
    state.known[POLYMORPH] = true
    state.emit("SPELLS_CHANGED")
    equal(macroBody(state, "! Polymorph"), "#showtooltip Polymorph\n/focus [@mouseover,harm,nodead]"
        .. "[nocombat,harm,nodead]\n/cast [@focus,harm,nodead] Polymorph")
    state.settings.MTF_POLYMORPH_MACRO:SetValue(false)
    equal(macroBody(state, "! Polymorph"), nil, "turning it off deletes it")
end)
test("the Polymorph bar follows your focus first, so it does not go blank when the plate drops", function()
    local state = mage({known = {[POLYMORPH] = true}})
    sheepTarget(state)
    state.units.nameplate4 = state.units.target
    state.units.focus = state.units.target
    castPolymorph(state)
    local bar = state.env.MageToolsForeverPolymorphBar
    equal(bar.container.unit, "focus")
    state.units.target = {name = "Defias Bandit", guid = "mob-2", level = 20}
    state.units.nameplate4 = nil
    state.emit("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    state.emit("PLAYER_TARGET_CHANGED")
    equal(bar.container.unit, "focus", "still bound while you fight another mob")
end)
test("unlocked, the Polymorph bar shows a sample to drag", function()
    local state = mage()
    state.slash("unlock")
    local bar = state.env.MageToolsForeverPolymorphBar
    equal(bar.shown, true)
    equal(bar.name.text, "Polymorph (sample)")
    equal(state.env.MageToolsForeverPolymorph.shown, true, "draggable before you learn Polymorph")
    state.slash("lock")
    equal(bar.shown, false)
    state.clear()
    state.slash("debug_polymorph")
    contains(state.messages[1], "debug_polymorph available=true known=false")
end)

-- Buff reminders --------------------------------------------------------------------

local INTELLECT, FROST_ARMOR = 1459, 168

local function reminderIcon(state, key)
    return state.env["MageToolsForeverReminder_" .. key]
end

test("a reminder icon shows while you lack a buff you know, with a pulsing border", function()
    local state = mage({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local intellect, armor = reminderIcon(state, "intellect"), reminderIcon(state, "armor")
    equal(intellect.shown, true)
    equal(intellect.glow.animation.playing, true, "the border pulses")
    equal(intellect.glow.animation.looping, "BOUNCE")
    equal(armor.shown, true)
    equal(reminderIcon(state, "dampen").shown, false, "off by default, and not known")
    state.buffs = {["Arcane Intellect"] = {name = "Arcane Intellect"}, ["Ice Armor"] = {name = "Ice Armor"}}
    state.emit("UNIT_AURA", "player")
    equal(intellect.shown, false)
    equal(intellect.glow.animation.playing, false)
    equal(armor.shown, false, "any armor counts")
    state.buffs = {["Arcane Brilliance"] = {name = "Arcane Brilliance"}}
    state.emit("UNIT_AURA", "player")
    equal(intellect.shown, false, "Arcane Brilliance counts")
    equal(armor.shown, true)
end)
test("reminders hide in combat, never read auras then, and come back after", function()
    local state = mage({known = {[INTELLECT] = true}})
    local intellect, holder = reminderIcon(state, "intellect"), state.env.MageToolsForeverReminders
    equal(intellect.shown, true)
    equal(holder.shown, true)
    equal(state.drivers[holder], "[combat] hide; show", "the game hides the secure icons for combat")
    state.combat = true
    state.applyDrivers()
    equal(holder.shown, false)
    state.buffs = {["Arcane Intellect"] = {name = "Arcane Intellect"}}
    state.emit("UNIT_AURA", "player")
    state.slash("unlock")
    equal(intellect.shown, true, "no aura read and no secure change in combat")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(holder.shown, true)
    equal(intellect.shown, true, "unlocked after combat: a sample to drag")
    equal(intellect.attributes.type1, nil, "dragging never casts")
end)
test("Arcane Intellect counts group members who use mana", function()
    local state = mage({known = {[INTELLECT] = true}})
    state.buffs = {["Arcane Intellect"] = {name = "Arcane Intellect"}}
    state.group = "party"
    state.units.party1 = {name = "Healy", class = "PRIEST", player = true, friend = true}
    state.units.party2 = {name = "Stabby", class = "ROGUE", player = true, friend = true}
    state.units.party3 = {name = "Faraway", class = "DRUID", player = true, friend = true, far = true}
    state.units.party4 = {name = "Shocky", class = "SHAMAN", player = true, friend = true}
    state.emit("GROUP_ROSTER_UPDATE")
    local intellect = reminderIcon(state, "intellect")
    equal(intellect.shown, true)
    equal(intellect.count.text, 2, "Healy and Shocky; not the rogue or someone out of sight")
    equal(table.concat(intellect.missing, ","), "Healy,Shocky")
    state.units.party1.buffs = {["Arcane Brilliance"] = {}}
    state.units.party4.buffs = {["Arcane Intellect"] = {}}
    state.emit("UNIT_AURA", "party1")
    equal(intellect.shown, false)
    state.units.party1.buffs = nil
    state.settings.MTF_REMINDER_GROUP:SetValue(false)
    equal(intellect.shown, false, "only you when the group option is off")
end)
test("clicking Arcane Intellect buffs you first, then each group member who lacks it", function()
    local state = mage({known = {[INTELLECT] = true}})
    local intellect = reminderIcon(state, "intellect")
    equal(intellect.protected, true, "a secure button")
    equal(intellect.attributes.type1, "spell")
    equal(intellect.attributes.spell1, "Arcane Intellect")
    equal(intellect.attributes.unit1, "player", "you first")
    state.buffs = {["Arcane Intellect"] = {name = "Arcane Intellect"}}
    state.group = "party"
    state.units.party1 = {name = "Stabby", class = "ROGUE", player = true, friend = true}
    state.units.party2 = {name = "Healy", class = "PRIEST", player = true, friend = true}
    state.units.party3 = {name = "Shocky", class = "SHAMAN", player = true, friend = true}
    state.env.C_Spell.IsSpellInRange = function(spell, unit) return unit ~= "party2" end
    state.emit("GROUP_ROSTER_UPDATE")
    equal(intellect.attributes.unit1, "party3", "the first in range; never the rogue")
    state.units.party3.buffs = {["Arcane Intellect"] = {}}
    state.emit("UNIT_AURA", "party3")
    equal(intellect.attributes.unit1, "party2", "out of range but the only one left")
    state.units.party2.buffs = {["Arcane Intellect"] = {}}
    state.emit("UNIT_AURA", "party2")
    equal(intellect.shown, false)
    equal(intellect.attributes.type1, nil, "nothing to cast")
end)
test("with two or more missing, Arcane Brilliance if you know it and carry Arcane Powder", function()
    local state = mage({known = {[INTELLECT] = true, [23028] = true}})
    local intellect = reminderIcon(state, "intellect")
    state.group = "party"
    state.units.party1 = {name = "Healy", class = "PRIEST", player = true, friend = true}
    state.emit("GROUP_ROSTER_UPDATE")
    equal(intellect.attributes.spell1, "Arcane Intellect", "no Arcane Powder")
    state.put(0, 1, 17020, 5)
    state.emit("BAG_UPDATE_DELAYED")
    equal(intellect.attributes.spell1, "Arcane Brilliance")
    state.buffs = {["Arcane Intellect"] = {name = "Arcane Intellect"}}
    state.emit("UNIT_AURA", "player")
    equal(intellect.attributes.spell1, "Arcane Intellect", "one missing: the single buff")
    equal(intellect.attributes.unit1, "party1")
end)
test("clicking Armor recasts the armor you used last, else your best", function()
    local state = mage({known = {[FROST_ARMOR] = true, [7302] = true}})
    local armor = reminderIcon(state, "armor")
    equal(armor.attributes.spell1, "Ice Armor", "your best")
    equal(armor.attributes.unit1, "player")
    state.cast(FROST_ARMOR)
    state.emit("UNIT_AURA", "player")
    equal(armor.attributes.spell1, "Frost Armor", "the one you used")
    equal(state.mtf.db.reminders.last.armor, "Frost Armor", "saved per character")
end)
-- Positions of a reminder icon's center on screen.
local function iconCenter(state, key)
    local icon = state.env["MageToolsForeverReminder_" .. key]
    local x, y = state.absCenter(icon)
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

local function drop(state, icon, x, y)
    icon.scripts.OnDragStart(icon)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", nil, "BOTTOMLEFT", x / icon:GetEffectiveScale(), y / icon:GetEffectiveScale())
    icon.scripts.OnDragStop(icon)
end

-- Drags a frame by a handle (a child that takes the drag) and drops it at x, y.
local function dropBy(state, frame, handle, x, y)
    handle.scripts.OnDragStart(handle)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", nil, "BOTTOMLEFT", x / frame:GetEffectiveScale(), y / frame:GetEffectiveScale())
    handle.scripts.OnDragStop(handle)
end

local function centerOf(state, frame)
    local x, y = state.absCenter(frame)
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

test("every MTF frame snaps, not only the buff reminders; Shift-drag moves a snapped group", function()
    local state = mage({known = {[3561] = true, [118] = true}})
    state.slash("unlock")
    local conjure, portals = state.env.MageToolsForeverConjure, state.env.MageToolsForeverPortals
    local polymorph = state.env.MageToolsForeverPolymorph
    dropBy(state, conjure, conjure, 300, 300)
    local cx, cy = centerOf(state, conjure)
    -- The portal bar, dropped near the conjure bar's right side, snaps 20 past it, tops aligned.
    local px = cx + conjure.width / 2 + 20 + portals.width / 2
    local py = cy + conjure.height / 2 - portals.height / 2
    dropBy(state, portals, portals, px + 7, py - 5)
    equal(select(1, centerOf(state, portals)), math.floor(px + 0.5))
    equal(select(2, centerOf(state, portals)), math.floor(py + 0.5))
    -- The Polymorph bar under the conjure bar, lefts aligned.
    local mx = cx - conjure.width / 2 + polymorph.width / 2
    local my = cy - conjure.height / 2 - 20 - polymorph.height / 2
    dropBy(state, polymorph, polymorph, mx + 4, my + 6)
    equal(select(1, centerOf(state, polymorph)), math.floor(mx + 0.5))
    equal(select(2, centerOf(state, polymorph)), math.floor(my + 0.5))
    equal(state.mtf.db.polymorph.position.relativePoint, "BOTTOMLEFT", "saved")
    -- Shift-drag the conjure bar: the portal and Polymorph bars come along.
    local portalX = select(1, centerOf(state, portals)) - cx
    state.shift = true
    dropBy(state, conjure, conjure, 600, 600)
    local nx, ny = centerOf(state, conjure)
    equal(select(1, centerOf(state, portals)) - nx, portalX, "the group kept its spacing")
    equal(select(2, centerOf(state, polymorph)), ny - (cy - math.floor(my + 0.5)))
end)

test("a Shift-dragged group that snaps to another frame keeps its spacing", function()
    local state = mage({known = {[3561] = true, [118] = true}})
    state.slash("unlock")
    local conjure, portals = state.env.MageToolsForeverConjure, state.env.MageToolsForeverPortals
    local icon = reminderIcon(state, "intellect")
    dropBy(state, conjure, conjure, 300, 300)
    local cx, cy = centerOf(state, conjure)
    dropBy(state, portals, portals, cx + conjure.width / 2 + 20 + portals.width / 2, cy)
    local gapX = select(1, centerOf(state, portals)) - cx
    -- Drop the group a little off the spot under the buff reminder, so it snaps.
    local ix, iy = state.absCenter(icon)
    local iconHalf = icon.height * icon:GetEffectiveScale() / 2
    local barHalfH = conjure.height * conjure:GetEffectiveScale() / 2
    local spotX, spotY = ix, iy - iconHalf - 20 - barHalfH
    state.shift = true
    dropBy(state, conjure, conjure, spotX + 6, spotY - 5)
    local nx, ny = centerOf(state, conjure)
    equal(nx, math.floor(spotX + 0.5), "the group snapped")
    equal(ny, math.floor(spotY + 0.5))
    equal(select(1, centerOf(state, portals)) - nx, gapX, "the portal bar kept its place beside it")
end)
test("a drop after combat began waits, then snaps and saves the group when combat ends", function()
    local state = mage({known = {[3561] = true}})
    state.slash("unlock")
    local conjure, portals = state.env.MageToolsForeverConjure, state.env.MageToolsForeverPortals
    dropBy(state, conjure, conjure, 300, 300)
    local cx, cy = centerOf(state, conjure)
    dropBy(state, portals, portals, cx + conjure.width / 2 + 20 + portals.width / 2, cy)
    local gapX = select(1, centerOf(state, portals)) - cx
    local saved = state.mtf.db.portals.position
    state.shift = true
    conjure.scripts.OnDragStart(conjure)
    conjure:ClearAllPoints()
    conjure:SetPoint("CENTER", nil, "BOTTOMLEFT", 500 / conjure:GetEffectiveScale(), 500 / conjure:GetEffectiveScale())
    state.combat = true
    conjure.scripts.OnDragStop(conjure)
    equal(state.mtf.db.portals.position, saved, "nothing saved in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.mtf.db.portals.position.relativePoint, "BOTTOMLEFT", "saved once combat ends")
    equal(select(1, centerOf(state, portals)) - select(1, centerOf(state, conjure)), gapX, "the group kept together")
    equal(conjure.moving, false, "stopped moving")
end)
test("reminder icons start in a row 20 apart, and a drop near another snaps beside it", function()
    local state = mage()
    state.slash("unlock")
    local intellect, armor, dampen = reminderIcon(state, "intellect"), reminderIcon(state, "armor"),
        reminderIcon(state, "dampen")
    state.mtf.db.reminders.spells.dampen = true
    state.mtf.RefreshReminders()
    local ix, iy = iconCenter(state, "intellect")
    local ax = iconCenter(state, "armor")
    equal(ax - ix, 60, "40 wide, 20 apart")
    -- Dropped a little off to the right of Armor: snaps 20 past it, in line.
    drop(state, intellect, ax + 64, iy + 9)
    local nx, ny = iconCenter(state, "intellect")
    equal(nx, ax + 60)
    equal(ny, iy, "aligned")
    -- Dropped far from everything: stays where it lands.
    drop(state, dampen, 100, 100)
    equal(select(1, iconCenter(state, "dampen")), 100)
    -- Below a bigger icon: the gap is between their edges.
    for _ = 1, 5 do armor.scripts.OnMouseWheel(armor, 1) end
    equal(state.mtf.db.reminders.icons.armor.scale, 150)
    local bx, by = iconCenter(state, "armor")
    drop(state, dampen, bx + 3, by - 70)
    local dx, dy = iconCenter(state, "dampen")
    equal(dx, bx)
    equal(dy, by - (30 + 20 + 20), "half of 60, the gap, half of 40")
end)
test("Shift-dragging an icon moves every icon snapped to it", function()
    local state = mage()
    state.mtf.db.reminders.spells.dampen = true
    state.slash("unlock")
    local intellect, armor, dampen = reminderIcon(state, "intellect"), reminderIcon(state, "armor"),
        reminderIcon(state, "dampen")
    local ix, iy = iconCenter(state, "intellect")
    local ax, ay = iconCenter(state, "armor")
    local dx, dy = iconCenter(state, "dampen")
    state.shift = true
    drop(state, intellect, ix - 300, iy - 100)
    equal(select(1, iconCenter(state, "armor")), ax - 300, "the row moves together")
    equal(select(2, iconCenter(state, "dampen")), dy - 100)
    equal(state.mtf.db.reminders.icons.dampen.position.relativePoint, "BOTTOMLEFT", "each saved on its own")
    -- Without Shift, one icon leaves the group.
    state.shift = false
    drop(state, intellect, 900, 700)
    equal(select(1, iconCenter(state, "armor")), ax - 300, "the others stay")
    -- A gap that is not the snap gap is not snapped.
    state.shift = true
    drop(state, armor, ax, ay)
    equal(select(1, iconCenter(state, "intellect")), 900)
end)
test("resizing an icon keeps its center", function()
    local state = mage()
    state.slash("unlock")
    local intellect = reminderIcon(state, "intellect")
    local x, y = iconCenter(state, "intellect")
    intellect.scripts.OnMouseWheel(intellect, 1)
    local nx, ny = iconCenter(state, "intellect")
    equal(nx, x)
    equal(ny, y)
end)
test("with Dyre's Buff Reminders loaded, MTF's reminders stay hidden and keep their settings", function()
    local state = mage({known = {[INTELLECT] = true, [FROST_ARMOR] = true},
        loadedAddOns = {DyresBuffReminders = true}})
    equal(reminderIcon(state, "intellect").shown, false, "no second icon beside Dyre's Buff Reminders'")
    equal(reminderIcon(state, "armor").shown, false)
    state.slash("unlock")
    equal(reminderIcon(state, "intellect").shown, false, "not even to drag")
    equal(state.mtf.db.reminders.spells.intellect, true, "the saved switch is untouched")
    local greyed = 0
    local page = state.categories["Buff Reminders (Dyre's Buff Reminders)"]
    equal(page.headings[1].heading, "Buff reminders are now managed by Dyre's Buff Reminders")
    contains(page.headings[1].tooltip, "/dbr")
    for _, name in ipairs({"Buff Reminders (Dyre's Buff Reminders)", "Mage Tools Forever"}) do
        for _, initializer in ipairs(state.categories[name].initializers) do
            local variable = initializer.setting and initializer.setting.variable or ""
            if variable:find("^MTF_REMINDER") then
                equal(initializer.modifyPredicates[1](), false, variable .. " is greyed out")
                contains(initializer.tooltip, "Dyre's Buff Reminders")
                greyed = greyed + 1
            end
        end
    end
    equal(greyed, #state.mtf.REMINDERS + 2, "every reminder switch, the group switch, and the main switch")
    local plain = mage()
    for _, initializer in ipairs(plain.categories["Buff Reminders"].initializers) do
        equal(#initializer.modifyPredicates, 0, "not greyed without Dyre's Buff Reminders")
    end
end)
test("unlocked, each reminder shows to drag and resizes with the mouse wheel", function()
    local state = mage()
    state.buffs = {["Arcane Intellect"] = {name = "Arcane Intellect"}}
    state.slash("unlock")
    local intellect = reminderIcon(state, "intellect")
    equal(intellect.shown, true, "shown to place, even unknown or buffed")
    equal(intellect.wheel, true)
    intellect.scripts.OnMouseWheel(intellect, 1)
    intellect.scripts.OnMouseWheel(intellect, 1)
    equal(state.mtf.db.reminders.icons.intellect.scale, 120)
    equal(intellect.scale, 1.2)
    equal(reminderIcon(state, "armor").scale, 1, "each icon on its own")
    intellect.scripts.OnDragStart(intellect)
    intellect:SetPoint("TOP", nil, "TOP", 5, -50)
    intellect.scripts.OnDragStop(intellect)
    equal(state.mtf.db.reminders.icons.intellect.position.relativePoint, "BOTTOMLEFT")
    equal(math.floor(state.mtf.db.reminders.icons.intellect.position.x * 1.2 + 0.5), 506, "where it was dropped: 5 past center at 120%")
    state.slash("lock")
    equal(intellect.shown, false)
    intellect.scripts.OnMouseWheel(intellect, 1)
    equal(state.mtf.db.reminders.icons.intellect.scale, 120, "locked icons do not resize")
    state.slash("reset")
    equal(state.mtf.db.reminders.icons.intellect.scale, 100)
    equal(state.mtf.db.reminders.icons.intellect.position, nil)
    state.clear()
    state.slash("debug_reminders")
    contains(state.messages[1], "debug_reminders intellect on=true known=false")
end)

test("unlocked, a grid shows the screen's center; it follows its switch and the lock", function()
    local state = mage()
    equal(state.mtf.grid, nil, "nothing built while locked")
    state.slash("unlock")
    local grid = state.mtf.grid
    equal(grid.shown, true)
    equal(grid.mouse, false, "never takes clicks")
    -- A 1000 x 800 screen, lines every 32 from the center: 15 + 15 + 12 + 12, then the two center lines.
    equal(#grid.lines, 56)
    local center = grid.lines[#grid.lines]
    equal(center.color[1], 1)
    equal(center.color[2], 0.2, "the center lines are red")
    equal(center.height, 2)
    state.settings.MTF_GRID:SetValue(false)
    equal(grid.shown, false)
    state.settings.MTF_GRID:SetValue(true)
    equal(grid.shown, true)
    state.slash("lock")
    equal(grid.shown, false)
end)

-- Settings pages ----------------------------------------------------------------

test("the settings have a main page and a page per module", function()
    local state = mage()
    local main = state.categories["Mage Tools Forever"]
    equal(state.registered, main)
    equal(main.initializers[1].setting.variable, "MTF_CONJURE_ENABLED")
    equal(main.initializers[2].setting.variable, "MTF_PORTALS_ENABLED")
    equal(main.initializers[3].setting.variable, "MTF_POLYMORPH_ENABLED")
    equal(main.initializers[4].setting.variable, "MTF_REMINDERS_ENABLED")
    equal(main.initializers[5].setting.variable, "MTF_SHIELD_ENABLED")
    equal(main.initializers[6].setting.variable, "MTF_CHIMES_ENABLED")
    equal(state.categories.Polymorph.parent, main)
    equal(state.categories["Buff Reminders"].parent, main)
    equal(state.categories.Portals.parent, main)
    equal(state.categories.Announce.parent, main)
    equal(state.categories.Announce.frame, state.mtf.announcePage, "a canvas page")
    equal(state.categories.Conjure.parent, main)
    equal(state.categories.Shield.parent, main)
    equal(state.categories["Cooldown Chimes"].parent, main)
    state.settings.MTF_CONJURE_ENABLED:SetValue(false)
    equal(state.env.MageToolsForeverConjure.shown, false)
end)
test("without the Settings API MTF runs and /mtf explains", function()
    local state = fixture({noSettings = true})
    equal(state.mtf.available, true)
    state.slash("")
    contains(state.last(), "settings page is unavailable")
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
