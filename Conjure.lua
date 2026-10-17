local addonName, MTF = ...

-- Conjure: water, food, and mana gem buttons on a small movable bar, and
-- character macros for action bars. The buttons are secure, so they work in
-- combat, but their actions can change only out of combat; changes wait for
-- combat to end.
--
-- Water and food (author-approved):
--   With a friendly player targeted, right-click conjures the best rank they
--   can use; left-click trades them the share stack size (default 10) of the
--   best they can use, or all you have of it if less; with none, MTF says to
--   conjure some first.
--   With no one targeted, right-click conjures the best rank you know and
--   left-click eats or drinks your best.
--   Middle-click always eats or drinks your best, whatever you target.
-- Food & Water (author-approved) does both at once, beside the separate
-- buttons: left-click trades both shares in one click, with one whisper, or
-- eats and drinks your best; middle-click always eats and drinks your best.
-- One click may cast only one spell, so right-click alternates conjuring water
-- and food with the game's own /castsequence.
-- Mana gems work like Healthstones, without trading: left- and middle-click
-- use your best gem; right-click conjures the best rank you do not carry. A
-- Mage who knows no gem rank yet gets a message; the "! Mana Gem" macro
-- appears once a rank is learned.

-- Ranks from lowest to highest: the conjure spell, the item it makes, and the
-- level the item needs, by Classic IDs (confirmed on Forever for ranks 1 to 3
-- of water and food). The client sends an item's level only once it has the
-- item's data, which it lacked for ranks the Mage did not carry, so the
-- Classic level stands in until then. /mtf debug_conjure shows what the
-- client knows.
local WATER = {
    {spell = 5504, item = 5350, level = 1},    -- Conjured Water
    {spell = 5505, item = 2288, level = 5},    -- Conjured Fresh Water
    {spell = 5506, item = 2136, level = 15},    -- Conjured Purified Water
    {spell = 6127, item = 3772, level = 25},    -- Conjured Spring Water
    {spell = 10138, item = 8077, level = 35},   -- Conjured Mineral Water
    {spell = 10139, item = 8078, level = 45},   -- Conjured Sparkling Water
    {spell = 10140, item = 8079, level = 55},   -- Conjured Crystal Water
}
local FOOD = {
    {spell = 587, item = 5349, level = 1},     -- Conjured Muffin
    {spell = 597, item = 1113, level = 5},     -- Conjured Bread
    {spell = 990, item = 1114, level = 15},     -- Conjured Rye
    {spell = 6129, item = 1487, level = 25},    -- Conjured Pumpernickel
    {spell = 10144, item = 8075, level = 35},   -- Conjured Sourdough
    {spell = 10145, item = 8076, level = 45},   -- Conjured Sweet Roll
    {spell = 28612, item = 22895, level = 55},  -- Conjured Cinnamon Roll
}
local GEMS = {
    {spell = 759, item = 5514},     -- Mana Agate
    {spell = 3552, item = 5513},    -- Mana Jade
    {spell = 10053, item = 8007},   -- Mana Citrine
    {spell = 10054, item = 8008},   -- Mana Ruby
}
-- Classic's level for Conjure Mana Agate, for the message before it is known.
local FIRST_GEM_LEVEL = 28

local KINDS = {
    water = {ranks = WATER, label = "Water", noun = "conjured water", spellName = "Conjure Water",
        icon = "Interface\\Icons\\INV_Drink_18", order = 1},
    food = {ranks = FOOD, label = "Food", noun = "conjured food", spellName = "Conjure Food",
        icon = "Interface\\Icons\\INV_Misc_Food_09", order = 2},
    both = {label = "Food & Water", noun = "conjured food and water", spellName = "Conjure Water or Conjure Food",
        order = 3},
    gem = {ranks = GEMS, label = "Mana Gem", noun = "mana gem", spellName = "Conjure Mana Agate",
        icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01", order = 4},
}
-- The kinds with ranks of their own, and the buttons on the bar.
local KIND_ORDER = {"water", "food", "gem"}
local BUTTON_ORDER = {"water", "food", "both", "gem"}
-- The kinds the Food & Water button serves.
local BOTH_KINDS = {"water", "food"}

local BUTTON_SIZE = 36
local BUTTON_GAP = 6
local PADDING = 6
local GOLD = {1, 0.82, 0}
local BROWN = {0.28, 0.16, 0.07, 0.85}
local DEFAULT_POINT = {"CENTER", "CENTER", 260, -140}
-- Secure buttons run PostClick for both the press and the release.
local REPEAT_MESSAGE_SECONDS = 0.3
-- Seconds a requested trade waits for the trade window to open.
local TRADE_WAIT = 10
local TRADE_SLOT_COUNT = 6
-- Seconds after the trade window opens that MTF waits for a freshly split
-- stack to settle: the server confirms the move, and the slot stays locked
-- until then (in client the placement found it locked and gave up).
local SETTLE_WAIT = 5
-- At most one trade whisper to the same player this often (author-approved):
-- water then food in one trade, or seconds, whisper once.
local WHISPER_REPEAT_SECONDS = 30
local TRADE_LOG_SIZE = 8

local REQUIRED = {
    {"C_SpellBook", "IsSpellKnown"}, {"C_Item", "GetItemCount"}, {"C_Item", "GetItemInfo"},
    {"C_Spell", "GetSpellName"}, {"C_Container", "GetContainerItemInfo"},
    {"C_Container", "PickupContainerItem"}, {"C_Container", "SplitContainerItem"},
    {"_G", "InitiateTrade"}, {"_G", "ClickTradeButton"}, {"_G", "GetTradePlayerItemLink"},
    {"_G", "GetCursorInfo"}, {"_G", "ClearCursor"},
}

local conjure = {pending = false, lastMessage = nil, lastMessageTime = 0, tradeLog = {}}
local buttons = {}

function MTF.CheckConjureCapabilities()
    for _, entry in ipairs(REQUIRED) do
        local namespace = entry[1] == "_G" and _G or _G[entry[1]]
        if type(namespace) ~= "table" or type(namespace[entry[2]]) ~= "function" then
            return false, entry[1] == "_G" and entry[2] or (entry[1] .. "." .. entry[2])
        end
    end
    return true
end

local function Known(spellID)
    return C_SpellBook.IsSpellKnown(spellID) == true
end

local function Carried(itemID)
    return C_Item.GetItemCount(itemID) or 0
end

local ITEM_LEVELS = {}
for _, ranks in ipairs({WATER, FOOD}) do
    for _, rank in ipairs(ranks) do
        ITEM_LEVELS[rank.item] = rank.level
    end
end

-- The client's level when it has the item's data, else Classic's.
local function MinLevel(itemID)
    local _, _, _, _, minLevel = C_Item.GetItemInfo(itemID)
    if type(minLevel) == "number" then
        return minLevel
    end
    return ITEM_LEVELS[itemID]
end

local function ItemName(itemID)
    local name = itemID and C_Item.GetItemInfo(itemID)
    return name
end

-- Whether a player of this level can use the item; nil level means you.
-- Item data may not be cached yet; until it is, the item does not fit.
local function Fits(itemID, level)
    if not level then
        return true
    end
    local required = MinLevel(itemID)
    return type(required) == "number" and required <= level
end

-- The best rank you know that a player of this level can use.
local function BestKnownRank(ranks, level)
    for index = #ranks, 1, -1 do
        local rank = ranks[index]
        if Known(rank.spell) and Fits(rank.item, level) then
            return rank
        end
    end
end

-- The best item you carry that a player of this level can use.
local function BestCarriedItem(ranks, level)
    for index = #ranks, 1, -1 do
        local item = ranks[index].item
        if Carried(item) > 0 and Fits(item, level) then
            return item
        end
    end
end

local function CountCarried(ranks)
    local total = 0
    for _, rank in ipairs(ranks) do
        total = total + Carried(rank.item)
    end
    return total
end

-- Each mana gem rank is unique in your bags, so a rank you carry is skipped
-- for the one below it, as Healthstones are; nil when you carry every rank.
local function GemRankToCreate()
    for index = #GEMS, 1, -1 do
        local rank = GEMS[index]
        if Known(rank.spell) and Carried(rank.item) == 0 then
            return rank
        end
    end
end

-- A friendly player target other than you, by level; nil otherwise.
local function TargetLevel()
    if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player")
        or not UnitIsFriend("player", "target") then
        return nil
    end
    local level = UnitLevel("target")
    if MTF.IsSecret(level) or type(level) ~= "number" or level < 1 then
        return nil
    end
    return level
end

-- The trade partner's unit token while a trade window is open, as the
-- client's TradeFrame uses it.
local TRADE_PARTNER = "NPC"

-- Whether a trade window is open: from TRADE_SHOW to TRADE_CLOSED, or
-- Blizzard's TradeFrame shown, in case an event was missed (in client a
-- second click once tried to open a trade while one was open).
local function TradeOpen()
    if conjure.tradeOpen then
        return true
    end
    if type(TradeFrame) == "table" and type(TradeFrame.IsShown) == "function" then
        local shown = TradeFrame:IsShown()
        return not MTF.IsSecret(shown) and shown == true
    end
    return false
end

-- While a trade is open, the buttons serve the trade partner, whoever you
-- target (author-approved: players often open a trade with the Mage);
-- otherwise your friendly player target.
local function FriendlyPlayerLevel()
    if TradeOpen() then
        local level = UnitLevel(TRADE_PARTNER)
        if not MTF.IsSecret(level) and type(level) == "number" and level >= 1 then
            return level
        end
    end
    return TargetLevel()
end

-- Macros --------------------------------------------------------------------
-- Character macros "! Water", "! Food", and "! Mana Gem" for action bars. On
-- Forever, /click does not press AddOn buttons (verified for WTF in client),
-- but a macro you own is secure. MTF keeps them current out of combat: left-
-- click eats, drinks, or uses your best; right-click conjures the rank the
-- button would. Each appears once you know a rank of its spell. They use the
-- question-mark icon, so #showtooltip shows the item; creation leaves your
-- last free character slots alone.
local MACRO_ICON = 134400
local MACRO_SLOT_CUSHION = 2
MTF.CONJURE_MACROS = {water = "! Water", food = "! Food", both = "! Food & Water", gem = "! Mana Gem"}

local macros = {warned = false}

-- MAX_CHARACTER_MACROS is a global only once Blizzard's Macro window has
-- loaded; the constant table always has it (found in client for WTF).
local function CharacterMacroLimit()
    local constants = type(Constants) == "table" and Constants.MacroConsts
    if type(constants) == "table" and type(constants.MAX_CHARACTER_MACROS) == "number" then
        return constants.MAX_CHARACTER_MACROS
    end
    if type(MAX_CHARACTER_MACROS) == "number" then
        return MAX_CHARACTER_MACROS
    end
end

-- The name /cast needs for an exact rank: "Conjure Water(Rank 4)".
local function CastName(spellID)
    local name = C_Spell.GetSpellName(spellID)
    local subtext = type(C_Spell.GetSpellSubtext) == "function" and C_Spell.GetSpellSubtext(spellID)
    if name and type(subtext) == "string" and subtext ~= "" then
        return name .. "(" .. subtext .. ")"
    end
    return name
end

function MTF.ConjureMacroBody(kind, rank)
    local ranks = KINDS[kind].ranks
    local best = BestCarriedItem(ranks)
    local shown = best or (rank and rank.item) or ranks[1].item
    local lines = {"#showtooltip item:" .. shown}
    local castName = rank and CastName(rank.spell)
    if castName then
        lines[#lines + 1] = "/cast [btn:2] " .. castName
        lines[#lines + 1] = "/stopmacro [btn:2]"
    end
    -- Every rank, best first: the first one you carry is used.
    for index = #ranks, 1, -1 do
        lines[#lines + 1] = "/use item:" .. ranks[index].item
    end
    return table.concat(lines, "\n")
end

-- Conjures water and food in turn: one click casts one spell, so each click
-- casts the next. Nil when you know neither.
local function ConjureBothLine(waterRank, foodRank)
    local names = {}
    for _, rank in ipairs({waterRank, foodRank}) do
        local name = rank and CastName(rank.spell)
        if name then
            names[#names + 1] = name
        end
    end
    if #names == 2 then
        return "/castsequence " .. table.concat(names, ", ")
    elseif #names == 1 then
        return "/cast " .. names[1]
    end
end

-- Eats and drinks: one /use per item; food and water share no cooldown.
local function UseBothLines(waterItem, foodItem)
    local lines = {}
    for _, itemID in ipairs({waterItem, foodItem}) do
        if itemID then
            lines[#lines + 1] = "/use item:" .. itemID
        end
    end
    return lines
end

-- The best carried of each, else the best you can conjure: the macro's /use
-- lines name one item each, so it stays within the 255-letter macro limit.
function MTF.ConjureBothMacroBody(waterRank, foodRank)
    local water = BestCarriedItem(WATER) or (waterRank and waterRank.item)
    local food = BestCarriedItem(FOOD) or (foodRank and foodRank.item)
    local lines = {"#showtooltip item:" .. (water or food or WATER[1].item)}
    local conjureLine = ConjureBothLine(waterRank, foodRank)
    if conjureLine then
        lines[#lines + 1] = conjureLine:gsub("^/(%a+) ", "/%1 [btn:2] ", 1)
        lines[#lines + 1] = "/stopmacro [btn:2]"
    end
    for _, line in ipairs(UseBothLines(water, food)) do
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

local function WriteMacro(name, body)
    local index = GetMacroIndexByName(name)
    if index == 0 then
        local _, numCharacter = GetNumMacros()
        if CharacterMacroLimit() - numCharacter <= MACRO_SLOT_CUSHION then
            if not macros.warned then
                macros.warned = true
                MTF.Report("No free character macro slot for \"" .. name .. "\"; free one and MTF adds it.")
            end
            return
        end
        CreateMacro(name, MACRO_ICON, body, true)
    elseif GetMacroBody(index) ~= body then
        EditMacro(index, name, MACRO_ICON, body)
    end
end

-- Macros change only out of combat; ApplyActions runs then.
local function UpdateMacros(createRanks)
    if not MTF.db.conjure.macros or not macros.available then
        return
    end
    for _, kind in ipairs(KIND_ORDER) do
        if BestKnownRank(KINDS[kind].ranks) then
            WriteMacro(MTF.CONJURE_MACROS[kind], MTF.ConjureMacroBody(kind, createRanks[kind]))
        end
    end
    if BestKnownRank(WATER) or BestKnownRank(FOOD) then
        WriteMacro(MTF.CONJURE_MACROS.both, MTF.ConjureBothMacroBody(createRanks.water, createRanks.food))
    end
end

-- Turning the macros off deletes them, out of combat.
function MTF.ApplyConjureMacros()
    if InCombatLockdown() then
        conjure.pending = true
        return
    end
    if MTF.db.conjure.macros then
        conjure.pending = true
        MTF.RefreshConjure()
        return
    end
    for _, name in pairs(MTF.CONJURE_MACROS) do
        local index = GetMacroIndexByName(name)
        if index > 0 then
            DeleteMacro(index)
        end
    end
end

-- Button actions ---------------------------------------------------------------

local function SetItemAction(button, suffix, itemID)
    button:SetAttribute("type" .. suffix, itemID and "item" or nil)
    button:SetAttribute("item" .. suffix, itemID and ("item:" .. itemID) or nil)
end

local function SetSpellAction(button, suffix, rank)
    button:SetAttribute("type" .. suffix, rank and "spell" or nil)
    button:SetAttribute("spell" .. suffix, rank and rank.spell or nil)
end

local function SetMacroAction(button, suffix, text)
    button:SetAttribute("type" .. suffix, text and "macro" or nil)
    button:SetAttribute("macrotext" .. suffix, text)
end

local function ApplyFoodOrWater(kind, level, createRanks)
    local ranks = KINDS[kind].ranks
    local button = buttons[kind]
    local own = BestCarriedItem(ranks)
    local rank
    if level then
        -- Left-click starts a trade from PostClick, so it has no secure action.
        rank = BestKnownRank(ranks, level)
        button.mode = "trade"
        button.tradeItem = BestCarriedItem(ranks, level)
        SetItemAction(button, "1", nil)
    else
        rank = BestKnownRank(ranks)
        button.mode = "use"
        button.tradeItem = nil
        SetItemAction(button, "1", own)
    end
    button.tradeItems = {[kind] = button.tradeItem}
    SetSpellAction(button, "2", rank)
    -- Middle-click always uses your own best, whatever your target (author-approved).
    SetItemAction(button, "3", own)
    button.itemID, button.rank, button.level = own, rank, level
    createRanks[kind] = rank
    local shownItem = button.tradeItem or (not level and own) or (rank and rank.item)
    button.icon:SetTexture(shownItem and C_Item.GetItemIconByID(shownItem) or KINDS[kind].icon)
    button.icon:SetDesaturated(BestKnownRank(ranks) == nil)
    local counted = level and button.tradeItem or own
    button.count:SetText(counted and Carried(counted) or "")
end

-- The Food & Water button, from the ranks and items the two buttons chose.
local function ApplyBoth(level, createRanks)
    local button = buttons.both
    local water, food = BestCarriedItem(WATER), BestCarriedItem(FOOD)
    local own = UseBothLines(water, food)
    local ownText = #own > 0 and table.concat(own, "\n") or nil
    if level then
        button.mode = "trade"
        button.tradeItems = {water = BestCarriedItem(WATER, level), food = BestCarriedItem(FOOD, level)}
        SetMacroAction(button, "1", nil)
    else
        button.mode = "use"
        button.tradeItems = {}
        SetMacroAction(button, "1", ownText)
    end
    SetMacroAction(button, "2", ConjureBothLine(createRanks.water, createRanks.food))
    SetMacroAction(button, "3", ownText)
    button.itemID = water or food
    button.rank = createRanks.water or createRanks.food
    button.level = level
    local shownWater = button.tradeItems.water or (not level and water) or (createRanks.water and createRanks.water.item)
    local shownFood = button.tradeItems.food or (not level and food) or (createRanks.food and createRanks.food.item)
    button.icon:SetTexture(shownWater and C_Item.GetItemIconByID(shownWater) or KINDS.water.icon)
    button.icon2:SetTexture(shownFood and C_Item.GetItemIconByID(shownFood) or KINDS.food.icon)
    local unknown = BestKnownRank(WATER) == nil and BestKnownRank(FOOD) == nil
    button.icon:SetDesaturated(unknown)
    button.icon2:SetDesaturated(unknown)
    button.count:SetText("")
end

local function ApplyGem(createRanks)
    local button = buttons.gem
    local own = BestCarriedItem(GEMS)
    local rank = GemRankToCreate()
    SetItemAction(button, "1", own)
    SetItemAction(button, "3", own)
    SetSpellAction(button, "2", rank)
    button.mode = "use"
    button.itemID, button.rank = own, rank
    createRanks.gem = rank
    local known = BestKnownRank(GEMS)
    local shownItem = own or (rank and rank.item) or (known and known.item)
    button.icon:SetTexture(shownItem and C_Item.GetItemIconByID(shownItem) or KINDS.gem.icon)
    button.icon:SetDesaturated(known == nil)
    button.count:SetText(own and CountCarried(GEMS) or "")
end

local function ApplyActions()
    if InCombatLockdown() then
        conjure.pending = true
        return
    end
    conjure.pending = false
    local level = FriendlyPlayerLevel()
    local createRanks = {}
    ApplyFoodOrWater("water", level, createRanks)
    ApplyFoodOrWater("food", level, createRanks)
    ApplyBoth(level, createRanks)
    ApplyGem(createRanks)
    UpdateMacros(createRanks)
end

local function UpdateVisibility()
    if InCombatLockdown() then
        conjure.pending = true
        return
    end
    buttons.bar:SetScale(MTF.db.conjure.scale / 100)
    if MTF.db.conjure.enabled then
        buttons.bar:Show()
    else
        buttons.bar:Hide()
    end
end

function MTF.RefreshConjure()
    if not buttons.bar then
        return
    end
    -- A plain child of the bar, so it can show and hide also in combat.
    buttons.bar.mover:SetShown(not MTF.db.conjure.locked)
    ApplyActions()
    UpdateVisibility()
end

local function Say(message)
    local now = GetTime()
    if message == conjure.lastMessage and now - conjure.lastMessageTime < REPEAT_MESSAGE_SECONDS then
        return
    end
    conjure.lastMessage, conjure.lastMessageTime = message, now
    MTF.Report(message)
end

-- A trade that cannot go ahead, said in chat and in red at the top of the
-- screen, where the game shows its own "Inventory is full" (author-approved:
-- never a click that seems to do nothing).
local WARNING_RED = {1, 0.1, 0.1}

local function Warn(message)
    Say(message)
    if type(UIErrorsFrame) == "table" and type(UIErrorsFrame.AddMessage) == "function" then
        UIErrorsFrame:AddMessage("MTF: " .. message, WARNING_RED[1], WARNING_RED[2], WARNING_RED[3])
    end
end

-- Trading -----------------------------------------------------------------------
-- The trade window holds bag slots, not what is on the cursor: a stack split
-- onto the cursor and dropped into a trade slot trades the whole stack it came
-- from (in client, a 10 share traded all 20). So at the click, a hardware
-- event, MTF picks whole stacks that fit the share and splits any remainder
-- into an empty bag slot; when the trade window opens, it moves those slots
-- in whole. The total is exactly the share stack size, never more
-- (author-approved: the rest is for the next party member).

local function LastBag()
    return type(NUM_TOTAL_EQUIPPED_BAG_SLOTS) == "number" and NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
end

-- Every unlocked stack of an item in your carried bags.
local function Stacks(itemID)
    local stacks = {}
    for bag = 0, LastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if type(info) == "table" and info.itemID == itemID and not info.isLocked then
                stacks[#stacks + 1] = {bag = bag, slot = slot, count = info.stackCount or 1}
            end
        end
    end
    return stacks
end

-- An empty slot in a general bag (bag family 0), where conjured food fits.
local function EmptySlot()
    for bag = 0, NUM_BAG_SLOTS do
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 0 then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                if not C_Container.GetContainerItemInfo(bag, slot) then
                    return bag, slot
                end
            end
        end
    end
end

-- Moves `amount` from a stack onto a bag slot: into it when empty, onto it
-- when it holds the same item (the client merges them). True when done.
local function MoveOnto(stack, amount, bag, slot)
    if amount >= stack.count then
        C_Container.PickupContainerItem(stack.bag, stack.slot)
    else
        C_Container.SplitContainerItem(stack.bag, stack.slot, amount)
    end
    local kind = GetCursorInfo()
    if kind ~= "item" then
        ClearCursor()
        return false
    end
    C_Container.PickupContainerItem(bag, slot)
    if GetCursorInfo() then
        ClearCursor()
        return false
    end
    return true
end

-- One bag slot holding exactly `count` of an item (author-approved: a single
-- stack, not 6 + 4), made now at the click, using no extra bag slot where it
-- can (bags are often full early on): a stack of exactly that size; else the
-- biggest smaller stack topped up from the others, smallest first (the client
-- merges a stack dropped on the same item); else, with only bigger stacks,
-- that much split off the smallest of them into an empty slot. Nil, a reason,
-- and the source stack's size when that cannot be done.
local function PrepareShare(itemID, count)
    local stacks = Stacks(itemID)
    if #stacks == 0 then
        return nil, "none"
    end
    table.sort(stacks, function(a, b) return a.count > b.count end)
    local base
    for _, stack in ipairs(stacks) do
        if stack.count == count then
            return {stack}
        end
        if not base and stack.count < count then
            base = stack
        end
    end
    if base then
        local need = count - base.count
        for index = #stacks, 1, -1 do
            local source = stacks[index]
            if need == 0 then
                break
            end
            if source ~= base then
                local take = math.min(source.count, need)
                if not MoveOnto(source, take, base.bag, base.slot) then
                    return nil, "split"
                end
                need = need - take
            end
        end
        return {{bag = base.bag, slot = base.slot, count = count - need}}
    end
    -- Only bigger stacks: the smallest of them, so big stacks stay whole.
    local source = stacks[#stacks]
    local bag, slot = EmptySlot()
    if not bag then
        return nil, "full", source.count
    end
    if not MoveOnto(source, count, bag, slot) then
        return nil, "split"
    end
    return {{bag = bag, slot = slot, count = count}}
end

local function FreeTradeSlot()
    for slot = 1, TRADE_SLOT_COUNT do
        if not GetTradePlayerItemLink(slot) then
            return slot
        end
    end
end

-- The latest trade events, for /mtf debug_conjure.
local function LogTrade(event, detail)
    table.insert(conjure.tradeLog, 1, {time = GetTime(), event = event, detail = detail or ""})
    conjure.tradeLog[TRADE_LOG_SIZE + 1] = nil
end

-- Moves the prepared bag slots into the trade window. A slot still locked
-- (a split the server has not confirmed) is waited for: ITEM_LOCK_CHANGED and
-- BAG_UPDATE_DELAYED try again, for up to SETTLE_WAIT seconds. The client may
-- allow moving items only during a key press or click; a refused move is put
-- back and the rest is tried once more at the next key press or click. MTF
-- never presses Trade for you.
local PlaceShare
function PlaceShare(retry)
    local share = conjure.pendingTrade
    if not share or not share.openedAt or GetCursorInfo() then
        return
    end
    while share.next <= #share.plan do
        local entry = share.plan[share.next]
        local tradeSlot = FreeTradeSlot()
        if not tradeSlot then
            break
        end
        -- A slot just split into may still show empty, the old item, or
        -- locked until the server confirms the move (in client it showed
        -- not yet filled at TRADE_SHOW); all of those are waited for.
        local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
        local settling = type(info) ~= "table" and "empty"
            or info.itemID ~= entry.itemID and "other item"
            or info.isLocked and "locked"
        if settling then
            if GetTime() - share.openedAt <= SETTLE_WAIT then
                if share.waiting ~= settling then
                    share.waiting = settling
                    LogTrade("waiting", string.format("bag %d slot %d %s", entry.bag, entry.slot, settling))
                end
                return
            end
            LogTrade("gave up", string.format("bag %d slot %d still %s", entry.bag, entry.slot, settling))
            break
        end
        C_Container.PickupContainerItem(entry.bag, entry.slot)
        local kind, itemID = GetCursorInfo()
        if kind ~= "item" or itemID ~= entry.itemID then
            ClearCursor()
            LogTrade("pickup failed", string.format("bag %d slot %d cursor %s", entry.bag, entry.slot,
                tostring(itemID)))
            if retry then
                break
            end
            MTF.RunOnNextInput(function() PlaceShare(true) end)
            return
        end
        conjure.placing, conjure.refused = true, false
        ClickTradeButton(tradeSlot)
        conjure.placing = false
        if conjure.refused or GetCursorInfo() then
            ClearCursor()
            LogTrade("refused", string.format("trade slot %d", tradeSlot))
            if retry then
                break
            end
            MTF.RunOnNextInput(function() PlaceShare(true) end)
            return
        end
        entry.placed = true
        share.next = share.next + 1
    end
    conjure.pendingTrade = nil
    local placed, missed = {}, {}
    for _, entry in ipairs(share.plan) do
        local text = entry.count .. " " .. (ItemName(entry.itemID) or KINDS[entry.kind].noun)
        if entry.placed then
            placed[#placed + 1] = text
        else
            missed[#missed + 1] = ItemName(entry.itemID) or KINDS[entry.kind].noun
        end
    end
    LogTrade("placed", #placed .. " of " .. #share.plan)
    if #placed > 0 then
        MTF.Report(table.concat(placed, " and ") .. " in the trade window. Press Trade to give it.")
    end
    if #missed > 0 then
        Warn("MTF could not put the " .. table.concat(missed, " and ") .. " into the trade window; drag it in yourself.")
    end
end

-- Your target's names: "First Last" for messages and "First-Last" to whisper.
-- On Forever every character has a last name, and a whisper to the first
-- name alone fails (found in client for WTF).
local function UnitNames(unit)
    local first, last = UnitName(unit)
    if MTF.IsSecret(first) or MTF.IsSecret(last) or type(first) ~= "string" then
        return nil
    end
    if type(last) == "string" and last ~= "" then
        return first .. " " .. last, first .. "-" .. last
    end
    return first, first
end

-- The whisper as the trade window opens (author-approved), as WTF's
-- Healthstone gift whisper does.
local function WhisperShare(share)
    local kind = #share.plan == 1 and share.plan[1].kind or "both"
    local announce = MTF.db.announce
    if not announce[kind .. "Whisper"] or not share.whisperTo then
        return
    end
    conjure.whispered = conjure.whispered or {}
    local now, last = GetTime(), conjure.whispered[share.whisperTo]
    if last and now - last < WHISPER_REPEAT_SECONDS then
        return
    end
    conjure.whispered[share.whisperTo] = now
    local message
    if #share.plan == 1 then
        local entry = share.plan[1]
        message = MTF.FormatShareWhisper(announce[entry.kind .. "WhisperText"], entry.count,
            ItemName(entry.itemID) or KINDS[entry.kind].noun, share.target)
    else
        local parts = {}
        for _, entry in ipairs(share.plan) do
            parts[#parts + 1] = entry.count .. " " .. (ItemName(entry.itemID) or KINDS[entry.kind].noun)
        end
        message = MTF.FormatShareWhisper(announce.bothWhisperText, nil, table.concat(parts, " and "), share.target)
    end
    local send = type(C_ChatInfo) == "table" and C_ChatInfo.SendChatMessage or SendChatMessage
    send(message, "WHISPER", nil, share.whisperTo)
    conjure.lastWhisper = share.whisperTo
end

-- A share's trade window is open: whisper, place it, and give up on a split
-- that never settles.
local function OpenShare(share)
    share.openedAt = GetTime()
    WhisperShare(share)
    PlaceShare(false)
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(SETTLE_WAIT + 0.1, function()
            if conjure.pendingTrade == share then
                PlaceShare(false)
            end
        end)
    end
end

-- The player a share goes to: the trade partner while a trade is open, else
-- your target.
local function ShareNames()
    if TradeOpen() then
        local target, whisperTo = UnitNames(TRADE_PARTNER)
        if target then
            return target, whisperTo
        end
    end
    return UnitNames("target")
end

-- Prepares one kind's share: its plan entry, or nil after saying why not.
local function PrepareKind(kind, itemID)
    local count = math.min(MTF.db.conjure.shareSize, Carried(itemID))
    local plan, reason, sourceCount = PrepareShare(itemID, count)
    local name = ItemName(itemID) or KINDS[kind].noun
    if not plan then
        -- A part of a stack cannot go into the trade window directly: it takes
        -- the whole stack, so a split needs a free bag slot.
        if reason == "full" then
            Warn(string.format("Sorry, your bags are full! Free one bag slot so MTF can split %d off your %d %s, "
                .. "then try again.", count, sourceCount, name))
        elseif reason == "none" then
            Warn("Your " .. name .. " is still busy from a moment ago; try again in a second.")
        else
            Warn("The game would not split the " .. name .. "; try again.")
        end
        return nil
    end
    local entry = plan[1]
    entry.kind, entry.itemID = kind, itemID
    return entry
end

-- A share: one stack per kind, water then food for the Food & Water button.
local function StartShare(button)
    local plan = {}
    for _, kind in ipairs(button.kind == "both" and BOTH_KINDS or {button.kind}) do
        local itemID = button.tradeItems and button.tradeItems[kind]
        if itemID then
            plan[#plan + 1] = PrepareKind(kind, itemID)
        end
    end
    if #plan == 0 then
        return
    end
    local target, whisperTo = ShareNames()
    local share = {plan = plan, next = 1, time = GetTime(), target = target, whisperTo = whisperTo}
    conjure.pendingTrade = share
    LogTrade("prepared", #plan .. " stack(s)")
    if TradeOpen() then
        -- A trade is already open: straight into it.
        OpenShare(share)
    else
        InitiateTrade("target")
    end
end

-- Clicks ------------------------------------------------------------------------

local function ExplainCreate(button)
    local kind = KINDS[button.kind]
    if button.kind == "gem" then
        if not BestKnownRank(GEMS) then
            Say(string.format("You learn %s at level %d.", kind.spellName, FIRST_GEM_LEVEL))
        else
            Say("You already carry every mana gem you can conjure.")
        end
    elseif button.kind == "both" then
        if not BestKnownRank(WATER) and not BestKnownRank(FOOD) then
            Say("You do not know Conjure Water or Conjure Food yet.")
        elseif button.level then
            Say(string.format("You know no Conjure Water or Conjure Food rank a level %d player can use.",
                button.level))
        end
    elseif not BestKnownRank(kind.ranks) then
        Say("You do not know " .. kind.spellName .. " yet.")
    elseif button.level then
        Say(string.format("You know no %s rank a level %d player can use.", kind.spellName, button.level))
    end
end

local function ExplainUse(button)
    local kind = KINDS[button.kind]
    if button.kind == "gem" and not BestKnownRank(GEMS) then
        Say(string.format("You learn %s at level %d.", kind.spellName, FIRST_GEM_LEVEL))
    else
        Say("No " .. kind.noun .. " in your bags. Right-click to conjure " .. (button.kind == "gem" and "one." or "some."))
    end
end

-- Explains a click that did nothing, and starts a share trade; the secure
-- action itself already ran.
local function PostClick(button, mouseButton, down)
    -- The press and the release both arrive here; act once.
    if down then
        return
    end
    if mouseButton == "RightButton" then
        if not button.rank then
            ExplainCreate(button)
        end
    elseif mouseButton == "LeftButton" and button.mode == "trade" then
        if next(button.tradeItems or {}) then
            StartShare(button)
        else
            Say(string.format("You have no %s a level %d player can use. Right-click to conjure some first.",
                KINDS[button.kind].noun, button.level))
        end
    elseif not button.itemID then
        ExplainUse(button)
    end
end

local function ShowBothTooltip(button)
    GameTooltip:SetText(KINDS.both.label, GOLD[1], GOLD[2], GOLD[3])
    if button.mode == "trade" then
        local names = {}
        for _, kind in ipairs(BOTH_KINDS) do
            local itemID = button.tradeItems[kind]
            if itemID then
                names[#names + 1] = ItemName(itemID) or KINDS[kind].noun
            end
        end
        if #names > 0 then
            GameTooltip:AddLine(string.format("Left-click: trade up to %d each of %s to your target, in one click.",
                MTF.db.conjure.shareSize, table.concat(names, " and ")), 1, 1, 1, true)
        else
            GameTooltip:AddLine("Left-click: you carry no food or water your target can use.", 0.7, 0.7, 0.7, true)
        end
    elseif button.itemID then
        GameTooltip:AddLine("Left-click: eat and drink your best.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Left-click: you carry no conjured food or water.", 0.7, 0.7, 0.7, true)
    end
    if button.rank then
        GameTooltip:AddLine("Right-click: conjure water, then food, in turn (one spell per click).", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Right-click: you know no rank to conjure here.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:AddLine("Middle-click: eat and drink your own best.", 1, 1, 1, true)
    if MTF.db.conjure.macros then
        GameTooltip:AddLine("For your action bars: the \"" .. MTF.CONJURE_MACROS.both
            .. "\" macro in your character macros does the same.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

local function ShowTooltip(button)
    local kind = KINDS[button.kind]
    if button.kind == "both" then
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        ShowBothTooltip(button)
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(kind.label, GOLD[1], GOLD[2], GOLD[3])
    if button.kind == "gem" and not BestKnownRank(GEMS) then
        GameTooltip:AddLine(string.format("You learn %s at level %d.", kind.spellName, FIRST_GEM_LEVEL),
            0.7, 0.7, 0.7, true)
        GameTooltip:Show()
        return
    end
    if button.mode == "trade" then
        if button.tradeItem then
            GameTooltip:AddLine(string.format("Left-click: trade up to %d %s to your target (you carry %d).",
                MTF.db.conjure.shareSize, ItemName(button.tradeItem) or kind.noun, Carried(button.tradeItem)),
                1, 1, 1, true)
        else
            GameTooltip:AddLine("Left-click: you carry none your target can use; right-click to conjure some.",
                0.7, 0.7, 0.7, true)
        end
    elseif button.itemID then
        GameTooltip:AddLine("Left-click: use " .. (ItemName(button.itemID) or kind.noun) .. ".", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Left-click: you carry none.", 0.7, 0.7, 0.7, true)
    end
    if button.rank then
        GameTooltip:AddLine("Right-click: conjure " .. (ItemName(button.rank.item) or kind.noun)
            .. (button.mode == "trade" and ", the best your target can use." or "."), 1, 1, 1, true)
    elseif button.kind == "gem" then
        GameTooltip:AddLine("Right-click: you already carry every gem you can conjure.", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:AddLine("Right-click: you know no rank your target can use.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:AddLine("Middle-click: use your best " .. kind.noun .. " yourself.", 1, 1, 1, true)
    if MTF.db.conjure.macros then
        GameTooltip:AddLine("For your action bars: the \"" .. MTF.CONJURE_MACROS[button.kind]
            .. "\" macro in your character macros eats, drinks, or uses on left-click and conjures on right-click.",
            0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

-- The bar ------------------------------------------------------------------------

local function SavePosition(bar)
    local point, _, relativePoint, x, y = bar:GetPoint()
    MTF.db.conjure.position = {point = point, relativePoint = relativePoint, x = x, y = y}
end

local function PlaceBar(bar)
    local position = MTF.db.conjure.position
    bar:ClearAllPoints()
    if position then
        bar:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        bar:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

local function StartDrag()
    if MTF.db.conjure.locked or InCombatLockdown() then
        return
    end
    buttons.bar:StartMoving()
end

local function StopDrag()
    buttons.bar:StopMovingOrSizing()
    SavePosition(buttons.bar)
end

local function CreateConjureButton(bar, name, kind)
    local button = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
    button.kind = kind
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint("LEFT", bar, "LEFT", PADDING + (KINDS[kind].order - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
    button:RegisterForClicks("AnyUp", "AnyDown")
    -- Act on the release, as WTF's buttons do; mouse clicks are unaffected.
    button:SetAttribute("useOnKeyDown", false)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    if kind == "both" then
        -- Half water, half food.
        button.icon:SetPoint("TOPLEFT")
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOM")
        button.icon:SetTexCoord(0.07, 0.5, 0.07, 0.93)
        button.icon2 = button:CreateTexture(nil, "ARTWORK")
        button.icon2:SetPoint("TOPLEFT", button, "TOP")
        button.icon2:SetPoint("BOTTOMRIGHT")
        button.icon2:SetTexCoord(0.5, 0.93, 0.07, 0.93)
    else
        button.icon:SetAllPoints()
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10})
    border:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button:SetScript("PostClick", PostClick)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", StartDrag)
    button:SetScript("OnDragStop", StopDrag)
    return button
end

function MTF.ResetConjurePosition()
    MTF.db.conjure.position = nil
    if not buttons.bar then
        return
    end
    if InCombatLockdown() then
        conjure.resetPending = true
        return
    end
    PlaceBar(buttons.bar)
end

-- /mtf conjure: what you carry and the share stack size.
function MTF.ReportConjureStatus()
    for _, kind in ipairs(KIND_ORDER) do
        local ranks = KINDS[kind].ranks
        local best = BestCarriedItem(ranks)
        if best then
            MTF.Report(string.format("%s: %d %s (best), %d in all.", KINDS[kind].label, Carried(best),
                ItemName(best) or ("item " .. best), CountCarried(ranks)))
        else
            MTF.Report(KINDS[kind].label .. ": none.")
        end
    end
    MTF.Report(string.format("Share stack size: %d.", MTF.db.conjure.shareSize))
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "TRADE_SHOW" then
        local share = conjure.pendingTrade
        LogTrade(event, share and (#share.plan .. " stack(s)") or "")
        conjure.tradeOpen = true
        -- The buttons now serve the trade partner.
        ApplyActions()
        if share and GetTime() - share.time <= TRADE_WAIT then
            OpenShare(share)
        else
            conjure.pendingTrade = nil
        end
        return
    elseif event == "TRADE_CLOSED" then
        LogTrade(event)
        conjure.tradeOpen = false
        conjure.pendingTrade = nil
        ApplyActions()
        return
    elseif event == "ITEM_LOCK_CHANGED" then
        PlaceShare(false)
        return
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if ... == addonName and conjure.placing then
            conjure.refused = true
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if conjure.resetPending then
            conjure.resetPending = false
            PlaceBar(buttons.bar)
        end
        if conjure.pending then
            MTF.RefreshConjure()
        end
        return
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "PLAYER_TARGET_CHANGED" then
        ApplyActions()
        return
    end
    if event == "BAG_UPDATE_DELAYED" then
        PlaceShare(false)
    end
    MTF.RefreshConjure()
end)

function MTF.InitializeConjure()
    macros.missing = nil
    for _, name in ipairs({"GetMacroIndexByName", "GetNumMacros", "GetMacroBody", "CreateMacro", "EditMacro",
        "DeleteMacro"}) do
        if type(_G[name]) ~= "function" then
            macros.missing = macros.missing or name
        end
    end
    if not CharacterMacroLimit() then
        macros.missing = macros.missing or "Constants.MacroConsts.MAX_CHARACTER_MACROS"
    end
    macros.available = macros.missing == nil
    if not macros.available and MTF.db.conjure.macros then
        MTF.Report("Conjure macros stay off: this client lacks " .. macros.missing .. ".")
    end
    local bar = CreateFrame("Frame", "MageToolsForeverConjure", UIParent, "BackdropTemplate")
    bar:SetSize(PADDING * 2 + BUTTON_SIZE * #BUTTON_ORDER + BUTTON_GAP * (#BUTTON_ORDER - 1), PADDING * 2 + BUTTON_SIZE)
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
    -- While unlocked: a bright outline and a hint, as the shield display has.
    bar.mover = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.mover:SetPoint("TOPLEFT", -4, 4)
    bar.mover:SetPoint("BOTTOMRIGHT", 4, -4)
    bar.mover:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
    bar.mover:SetBackdropBorderColor(1, 0.82, 0)
    bar.mover.hint = bar.mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.mover.hint:SetPoint("BOTTOM", bar.mover, "TOP", 0, 2)
    bar.mover.hint:SetText("Drag to move · /mtf lock when done")
    bar.mover:Hide()
    buttons.bar = bar
    buttons.water = CreateConjureButton(bar, "MageToolsForeverWater", "water")
    buttons.food = CreateConjureButton(bar, "MageToolsForeverFood", "food")
    buttons.both = CreateConjureButton(bar, "MageToolsForeverFoodAndWater", "both")
    buttons.gem = CreateConjureButton(bar, "MageToolsForeverManaGem", "gem")
    PlaceBar(bar)
    -- Level requirements need item data, which arrives later on first use.
    if type(C_Item.RequestLoadItemDataByID) == "function" then
        for _, kind in ipairs(KIND_ORDER) do
            for _, rank in ipairs(KINDS[kind].ranks) do
                C_Item.RequestLoadItemDataByID(rank.item)
            end
        end
    end
    for _, event in ipairs({"BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "PLAYER_TARGET_CHANGED",
        "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED", "PLAYER_LEVEL_UP", "TRADE_SHOW", "TRADE_CLOSED",
        "ITEM_LOCK_CHANGED",
        "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "PLAYER_ENTERING_WORLD"}) do
        events:RegisterEvent(event)
    end
    MTF.RefreshConjure()
end

-- /mtf debug_click: what each conjure button does for each mouse button.
function MTF.ReportClickDebug()
    local function Report(text)
        MTF.Report("debug_click " .. text)
    end
    if not buttons.bar then
        Report("the conjure buttons do not exist")
        return
    end
    Report(string.format("combat=%s targetLevel=%s", tostring(InCombatLockdown()), tostring(FriendlyPlayerLevel())))
    for _, kind in ipairs(BUTTON_ORDER) do
        local button = buttons[kind]
        Report(string.format("%s mode=%s tradeItem=%s", button:GetName(), tostring(button.mode),
            tostring(button.tradeItem)))
        for index = 1, 3 do
            Report(string.format("  button%d type=%s item=%s spell=%s macro=%s", index,
                tostring(button:GetAttribute("type" .. index)), tostring(button:GetAttribute("item" .. index)),
                tostring(button:GetAttribute("spell" .. index)), tostring(button:GetAttribute("macrotext" .. index))))
        end
    end
end

-- /mtf debug_conjure: each rank's spell and item as the client knows them, to
-- confirm Forever's IDs and level requirements, plus macros and recent trades.
function MTF.ReportConjureDebug()
    local available, missing = MTF.CheckConjureCapabilities()
    if not available then
        MTF.Report("debug_conjure missing " .. missing)
        return
    end
    for _, kind in ipairs(KIND_ORDER) do
        for _, rank in ipairs(KINDS[kind].ranks) do
            MTF.Report(string.format("debug_conjure %s spell=%d name=%s known=%s item=%d itemName=%s carried=%d minLevel=%s",
                kind, rank.spell, tostring(CastName(rank.spell)), tostring(Known(rank.spell)), rank.item,
                tostring(ItemName(rank.item)), Carried(rank.item), tostring(MinLevel(rank.item))))
        end
    end
    MTF.Report(string.format("debug_conjure targetLevel=%s shareSize=%d pending=%s whisper=%s lastWhisper=%s",
        tostring(FriendlyPlayerLevel()), MTF.db and MTF.db.conjure.shareSize or 0, tostring(conjure.pending),
        tostring(MTF.db and MTF.db.announce.waterWhisper), tostring(conjure.lastWhisper)))
    local now = GetTime()
    for _, entry in ipairs(conjure.tradeLog) do
        MTF.Report(string.format("debug_conjure trade %.1fs ago %s %s", now - entry.time, entry.event, entry.detail))
    end
    if type(GetNumMacros) == "function" and type(GetMacroIndexByName) == "function" then
        local _, numCharacter = GetNumMacros()
        MTF.Report(string.format("debug_conjure macros enabled=%s available=%s missing=%s limit=%s used=%s",
            tostring(MTF.db and MTF.db.conjure.macros), tostring(macros.available), tostring(macros.missing),
            tostring(CharacterMacroLimit()), tostring(numCharacter)))
        for _, kind in ipairs(BUTTON_ORDER) do
            local name = MTF.CONJURE_MACROS[kind]
            MTF.Report(string.format("debug_conjure macro %q index=%d", name, GetMacroIndexByName(name)))
        end
    end
end
