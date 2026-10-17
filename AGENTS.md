# Agent Guidelines

## Project purpose and scope

Mage Tools Forever (MTF) is a World of Warcraft: Forever AddOn: a suite of
quality-of-life tools for Mages, the counterpart of the author's Warlock Tools
Forever (WTF). Each tool has its own switch on the main settings page and its
own subpage. Keep this feature set; do not add speculative features or
frameworks without agreement.

### Conjure (built)

- A small movable bar (gold-bordered brown panel, 36 px gold-bordered buttons)
  with Water, Food, Food & Water, and Mana Gem secure buttons, and character
  macros "! Water", "! Food", "! Food & Water", and "! Mana Gem" (Connoisseur's "- Name" style, with
  "!" to sort first; macro names hold at most 16 letters).
- Water and food (author-approved):
  - With a friendly player targeted (not you), right-click conjures the best
    rank you know whose item that player's level can use (item level
    requirement from `C_Item.GetItemInfo`); left-click has no secure action:
    PostClick on release calls `InitiateTrade("target")`, and on `TRADE_SHOW`
    within 10 s MTF puts exactly the share stack size into the trade window,
    or all you carry of that item if less. With none they can use, MTF says to
    conjure some first.
  - The share stack size is a setting from 1 to 20, default 10. Never trade
    more than it, however much you carry: Mages conjure for a whole party.
  - Placement: the trade window holds bag slots, not the cursor; a split
    dropped into a trade slot traded the whole source stack in client (20 for
    a share of 10). So at the click (a hardware event) MTF makes one bag slot
    holding exactly the share (author-approved: a single stack, not 6 + 4),
    using no extra bag slot where it can, since bags are often full early on:
    a stack of exactly that size; else the biggest smaller stack topped up
    from the others, smallest first (the client merges a cursor stack dropped
    on the same item; a split from a big stack is fine); else, with only
    bigger stacks, that much split off the smallest of them into an empty
    general-bag slot (`SplitContainerItem`, then `PickupContainerItem` on the
    empty slot). With only bigger stacks and no empty slot, it says how much
    it needs to split from which stack and trades nothing: never the whole
    stack. A trade that cannot go ahead (full bags, a busy stack, a refused
    split, a placement given up) is said in chat and in red at the top of
    the screen via `UIErrorsFrame` (author-approved: never a silent click). On
    `TRADE_SHOW` it picks up the prepared slot whole and `ClickTradeButton`s it. A
    prepared slot still locked (a split the server has not confirmed; in
    client the split worked but nothing reached the trade window) is waited
    for: `ITEM_LOCK_CHANGED` and `BAG_UPDATE_DELAYED` retry for up to 5 s,
    then MTF says to drag it in. A refused placement is put back and the rest
    retried once on the next key press or world click. MTF never presses Trade.
  - Whisper (author-approved, on by default): on `TRADE_SHOW` for an MTF
    trade, to the target's "First-Last" name, with `%C` count, `%I` item, `%T`
    full name; default texts credit MTF. Water, Food, and Food & Water each
    have their own switch and editable text on the Announce page. At most one
    whisper per player every 30 s (author-approved), so water then food in one
    trade whispers once.
  - A trade someone else opened (author-approved: players often run up and
    open one): from `TRADE_SHOW` to `TRADE_CLOSED` the buttons serve the
    trade partner (unit `NPC`, as TradeFrame uses it) instead of your target,
    by their level; left-click prepares the share and places it straight into
    the open window, with the whisper, and starts no new trade. A trade counts
    as open between those events or while Blizzard's `TradeFrame` is shown (in
    client a second click once tried to start a trade into an open one).
    Water then food in one trade each go in, each with its whisper.
  - With no one targeted, right-click conjures your best rank and left-click
    eats or drinks your best.
  - Middle-click always eats or drinks your own best, whatever the target.
- Food & Water (author-approved), third on the bar, beside the separate
  buttons, which stay as they are: left-click trades both shares in one click
  (one stack each, one whisper with the `both` text) or, untargeted, eats and
  drinks your best (macro `/use` water then `/use` food: two item uses in one
  click are allowed); middle-click always eats and drinks your own best.
  Right-click conjures water and food in turn with `/castsequence` (one
  click casts one spell; never cast two from one click). Macro
  "! Food & Water" uses the best carried item of each, to stay within 255
  letters. Its icon is half water, half food.
- Size settings (author-approved): conjure bar and shield display, 50-150%
  in steps of 5, default 100; the bar's applies out of combat (secure
  buttons), the shield's at once.
- Mana gems (author-approved): like WTF's Healthstones without trading.
  Left- and middle-click use your best gem; right-click conjures the best rank
  you do not carry (each rank is unique in your bags). Before a gem rank is
  known (Conjure Mana Agate comes at level 28), the button is desaturated and
  clicks say when it comes; the "! Mana Gem" macro is not written until a rank
  is known.
- Macros live in the character tab with the question-mark icon (134400), are
  rewritten out of combat only when the body changes, leave the last 2
  character slots free, and are deleted when "Keep conjure macros" is turned
  off. Bodies: `#showtooltip`, `/cast [btn:2] <rank>`, `/stopmacro [btn:2]`,
  then `/use item:` for every rank, best first. Ranks are cast by exact name,
  "Conjure Water(Rank 3)", from `C_Spell.GetSpellSubtext`.
  `Constants.MacroConsts.MAX_CHARACTER_MACROS` gives the slot limit; the global
  exists only after Blizzard's Macro window loads.
- Secure attributes change only out of combat; changes wait for
  `PLAYER_REGEN_ENABLED`.
- Spell and item IDs are Classic's (confirmed in client for water and food
  ranks 1-3); `/mtf debug_conjure` prints what the client knows. The client
  sends an item's level only once it has the item's data (not for ranks the
  Mage does not carry), so each rank's Classic required level stands in
  until then.

### Shield display (built; a shared component)

- Shield.lua is self-contained (author-approved, important): it uses nothing
  from MTF and takes only a settings table getter and a report function in
  `ShieldDisplay.Initialize`, so it can ship unchanged in other AddOns (a
  standalone shield AddOn, WTF, Priest or Paladin tools). It owns its
  defaults (`ShieldDisplay.Sanitize`). Core adapts it for MTF
  (`MTF.InitializeShield` and friends); the ring texture path follows the
  host's folder, so each host ships Textures/ShieldArc.tga.
- Duplicates reconcile to one ring: each copy registers in the global
  `ShieldForeverRegistry` as its file loads (before any `PLAYER_LOGIN`), and
  takes part only once its AddOn calls `Initialize` (MTF stays off on a
  Warlock, WTF on a Mage), so login order never decides. Among the copies
  taking part, the newest `VERSION`, then the first registered, draws the
  ring; a copy that was drawing stands down when a newer one joins (protocol
  2: each copy's start and stop are in the registry); the others draw
  nothing and say once which AddOn shows it. Version 1 copies elect among
  every registered copy. WTF ships the same file: keep both copies identical
  and bump `VERSION` in both with every behavior change.
- Version 3: bubbles (Divine Shield, Divine Protection: Paladin; Blessing
  of Protection: anyone) are timed, drawing a gold innermost crescent
  (Textures/ShieldArcInnermost.tga) that drains with their time left
  (Classic IDs; check on Forever). In combat the display stays shown, since
  buffs others cast cannot be read: the outer crescent is invisible with no
  absorb, and the engine shows each icon and timed crescent only while its
  buff is up.
- The icon row holds the player's own class's shields (`class` on each
  entry), then the shared ones (Power Word: Shield), one spot each: a Mage's
  Ice Barrier, Mana Shield, Fire Ward, Frost Ward, Power Word: Shield; a
  Warlock's Shadow Ward, Sacrifice, Power Word: Shield. Break sounds cover
  the same shields. Any other absorb fills the crescent in the other-shield
  color without an icon; Paladin bubbles are immunities with no absorb.
- A segmented crescent (white, tinted per shield) to the right of your
  character, filled from the bottom by a vertical StatusBar with your
  remaining absorb from any source, against the shield's size as it landed
  (author-approved, after NaN Shield; measuring against maximum health, as
  frame AddOns shade absorbs, filled too little to read). The size is the
  absorb total captured at your shield cast and in the next 0.5 s, or at the
  absorb change that starts another player's shield window: stored and passed
  to `SetMinMaxValues`, never read; maximum health until one is known. The
  number sits under the crescent; a dim track shows the used part. Known colors: Ice Barrier, Mana Shield, Fire Ward, Frost Ward,
  Power Word: Shield, Shadow Ward, Sacrifice; any other absorb (another
  player's, a trinket, a Forever Paladin shield) shows in a neutral color. The
  amount shows as a number (a setting, on by default).
- `UnitGetTotalAbsorbs` is always secret. It is passed, unread, to
  `StatusBar:SetValue`/`SetMinMaxValues`, through `AbbreviateNumbers` to
  `FontString:SetText`, and as the opacity (`SetAlpha`) of the frame holding
  everything visible, all `AllowedWhenTainted` in the pinned docs; opacity
  stops at 1, so the ring drops the moment the absorb is 0, also in combat
  (author: important). Curve objects refuse secrets from AddOn code, so
  never try to derive values from the absorb. Never compare or do math on it.
- Two kinds of shield (author-approved, like frame AddOns' absorb shading):
  absorb shields (Ice Barrier, the wards, Power Word: Shield) live in the
  outer crescent, which moves only as they absorb and drops when they break
  or expire; shields with no absorb amount (`timed`: Mana Shield) get the
  inner crescent (Textures/ShieldArcInner.tga, same center), driven by the
  AuraContainer slot's `SetDurationBar` (RemainingTime), so it drains with
  the time left and disappears with the buff, also in combat. That slot's
  frame covers the display and never takes the mouse; its icon sits in its
  spot. Only absorb shields color the outer crescent (the latest one up); a
  timed shield keeps the display up but never colors it (in client a Mana
  Shield cast after a ward turned both crescents purple).
- Several shields at once (Ice Barrier, Mana Shield, a ward): the client
  gives AddOns only the combined absorb, so the crescent shows the total,
  re-captured as each shield lands (author-approved). An icon row under the
  number shows which shields are up: a Blizzard AuraContainer (as WTF's DoT
  tracker) on `player`, filter `HELPFUL`, a slot per known shield with
  `includeSpellIDs` = a set `{[rankID] = true}` of its ranks (a list matches
  nothing, found in client) (Classic IDs match on Forever: Mana Shield
  1463, Fire Ward 543), icon and cooldown swipe; the engine shows and hides
  each icon, also in combat. `IsShown` on those icons is secret to AddOn code
  (found in client), so each shield has a fixed spot (mage shields 1-4,
  others share 5); never lay them out by visibility. The row sits outside the
  opacity frame, so a shield the total leaves out still shows its icon:
  Mana Shield is not in `UnitGetTotalAbsorbs` on Forever (its buff has no
  points; Fire Ward's points matched the total). Without
  the AuraContainer template the row is left out.
- Show/hide windows (a backstop to the opacity): your own shield cast (by
  name, any rank) for the shield's Classic length; any absorb change while no
  known shield is up, or just ended, for 30 s; out of combat your buffs are
  read (`GetAuraDataBySpellName`), so shields that broke early end and
  shields others cast on you show. Aura APIs error in combat; never call them
  then.
- A plain frame, locked by default; it takes the mouse only while unlocked, to
  show a sample of every part to drag, so it never blocks world clicks.

### Moving frames (built)

- One lock for every MTF frame (author-approved): `db.locked`, default
  locked, copied to each frame's own `locked` (the shield component reads its
  settings). The main page's "Unlock frames to move them" and `/mtf unlock`
  and `/mtf lock` set it; there are no per-frame lock switches. Every frame
  shows a gold outline and a "Drag to move · /mtf lock when done" hint while
  unlocked (the shield display also a full sample). Every new movable frame
  joins this lock.
- While unlocked, an alignment grid (author-approved; main-page switch "Show
  a grid while unlocked", on by default, `db.grid`): a mouse-transparent
  BACKGROUND-strata frame over UIParent with faint white lines every 32 units
  from the center out and the two center lines in red, 2 thick. Built on
  first unlock and rebuilt on `DISPLAY_SIZE_CHANGED` and `UI_SCALE_CHANGED`.
- Optional sound when a shield ends (off by default): `C_UnitAuras.AddAuraSound`
  with trigger Removed for every Classic rank ID, deferred during encounters.

### Cooldown chimes (built)

- A sound just before a chosen spell's cooldown ends (author-approved, after
  MageAlert), also in combat. Spells, defaults on: Blink, Frost Nova,
  Counterspell, Ice Block, Ice Barrier, Mana Shield, Evocation; off: Cold Snap,
  Fire Ward, Frost Ward, Cone of Cold, Fire Blast, Presence of Mind, Arcane
  Power, Combustion. Each has a switch.
- The combat log is closed to AddOns and `C_Spell.GetSpellCooldown` is secret
  under cooldown restrictions, with no event when a cooldown ends. So MTF times
  each chime from your own cast: the length it last read for that spell out of
  combat (saved per character), else the Classic length, minus the lead
  (setting 0-3 s in 0.5 s steps, default 0.5, as MageAlert's 14.5 s Blink).
  0.1 s after a cast it reads the real cooldown when readable and reschedules.
  Cold Snap cancels the Frost chimes. Mana Shield has no Classic cooldown and
  chimes only if the client reports one.
- Each chime has its own sound (author-approved), picked under its switch
  from one dropdown with nested menus like the Cooldown Manager's sound
  picker (author-approved, after its screenshot): a submenu per group (the
  part of each label before ": "), a top-level entry for a sound with no
  group (Text to Speech, last), the full label as the selection text, and no
  steppers. Blizzard's settings dropdown builds its menu in its control's
  `SetupDropdownMenu`; MTF wraps that method on the pooled control and builds
  `CreateButton` submenus of `CreateRadio` entries (as
  `CooldownViewerUtil.BuildSoundMenus` does) only for an initializer marked
  `mtfSoundMenu`, handing every other dropdown back to Blizzard's. Choosing a
  sound plays it. The sounds: SOUNDKIT names from the pinned SoundKitConstants, played with
  `PlaySound(kit, "Master")` (names the client lacks are left out), all 93 of
  the Cooldown Manager's alert sounds by kit ID in its categories (Animals,
  Devices, Impacts, Instruments, Short, Warcraft 2, Warcraft 3, as its menu
  names War2 and War3; author-approved: the
  same scheme, labels "Category: Name", generated from the pinned
  CooldownViewerSoundAlertData.lua; the old `popclick` key maps to
  `impactspopclick`), or
  "Text to Speech" (says "<Spell> ready") through `C_VoiceChat.SpeakText`
  (`AllowedWhenTainted`), with the player's TTS voice, rate, and volume from
  `C_TTSSettings`, offered only when a voice exists. Every spell defaults to
  Interface: Talent ready (author-approved: a good sound for a spell becoming
  available; players discover they can change it); a sound chosen for all
  chimes before each had its own (`chimes.sound`, read once) carries over.
  MageAlert's own sound files are not ours to ship.

### Portals (built)

- A movable bar (author-approved, after PortalMage) with a secure button for
  each teleport and portal you know (Classic IDs), teleports first, and the
  Rune of Teleportation or Rune of Portals count on each. The count is
  display only: never block or refuse a teleport or portal because the rune
  count is zero. The author's Mage uses legacy talents that make portals
  work without reagents; the game decides. Which spells the buttons hold
  changes only out of combat (`SPELLS_CHANGED`, applied after combat);
  counts update on `BAG_UPDATE_DELAYED`, also in combat. Hidden with nothing
  known, except while unlocked. Its own switch and Bar size (50-150%). Joins
  the one frame lock.
- A portal you open (`UNIT_SPELLCAST_SUCCEEDED`, matched by name) is told
  to your raid or party once (5 s), never to Say and never when alone.
- A teleport you cast emotes (author-approved, on by default; "summons
  powerful arcane energies to whisk themselves away to %Z"; `%T` your name, `%Z` your
  zone when sent: after the loading screen, the destination). Emotes are blocked
  outside a hardware event, so it is sent at your next key press or click
  within 60 s of the cast (after the loading screen), as WTF's emotes.

### Announce (built)

- A canvas settings page, as WTF's: a switch and a three-line, one-chat-line
  edit box per message (water, food, and Food & Water trade whispers; the
  portal group message and the teleport emote, `%D` the city, `%Z` your zone
  when the emote is sent; the Polymorph group message, `%T` the mob). Enter or focus loss keeps an edit
  (newlines become spaces; empty or over 255 bytes is the default), Escape
  undoes, and the panel's Defaults restores the page. The old single
  `conjure.whisper` switch carries over to the three whisper switches.

### Polymorph bar (built)

- One block in WTF's Bars format (author-approved; only one Polymorph of
  yours is up at a time): the mob's name above one bar line, an
  AuraContainer slot (`HARMFUL|PLAYER`, `includeSpellIDs` = Classic Polymorph,
  Pig, Turtle, and Cow IDs plus spellbook spells of those names) that the
  engine draws with `SetDurationBar` (RemainingTime), `SetSpellName`, and
  `SetDurationText`; a dim line behind it shows a broken Polymorph. The mob
  comes from your own cast events: `UNIT_SPELLCAST_SENT` names the target,
  matched to a unit for its GUID; on `UNIT_SPELLCAST_SUCCEEDED` the bar binds
  to the mob's nameplate, else target, focus, or mouseover, rebinding on
  target, focus, and nameplate changes. It forgets the mob when it dies
  (`UNIT_HEALTH`), after the longest Polymorph (50 s) plus 5 s, or on the
  next Polymorph. MTF never reads the aura; a resist cannot be seen (the
  combat log is closed), so a successful cast counts as landed.
- On cast start (`UNIT_SPELLCAST_SENT`, author-approved), the group message
  "Sheeping %T; you spank it, you tank it" (the author's classic line, no
  credit), raid or party only, at most once per 3 s; switch and text on the
  Announce page.
- When the cast succeeds, the moon raid marker (index 5) via `SetRaidTarget`,
  skipped when the mob already has the moon; switch on the Polymorph page, on by
  default. In a raid only leaders and assistants can mark.
- "! Polymorph" (author-approved, after the author's own, `polymorph.macro`):
  once you know Polymorph, `#showtooltip`, `/focus [@mouseover,harm,nodead]
  [nocombat,harm,nodead]`, `/cast [@focus,harm,nodead] Polymorph`. It does not
  `/tm`: MTF marks on landing, and a second mark would toggle it off.
  The bar finds the sheep through your focus, then target, then its nameplate.
- Click to re-sheep (author-approved, "if we can"; on your focus first since
  the author's focus workflow: `/cast [@focus,harm,nodead] <spell>`,
  `/stopmacro [@focus,exists]`, then by name): the bar sits on a secure
  button (`MageToolsForeverPolymorph`, the drag anchor); the visible bar is an
  ordinary frame anchored to it, so it shows and hides in combat. The macro is
  `/cleartarget`, `/targetexact <mob>`, `/cast [@target,harm,nodead]
  <the Polymorph you cast>`, `/targetlasttarget`: a missing mob leaves no
  target, so nothing else is sheeped. Attributes change only out of combat;
  a Polymorph begun in combat on another mob updates the click when combat
  ends, and until then the bar names the mob its click still sheeps. A cast
  that fails out of combat gives the click back to the sheep that is up.
  The holder (and the bar with it) is scaled only there too: in client, a
  recast from the bar that landed in combat rescaled the secure holder, and
  every click after failed. Tests make secure frames refuse SetScale,
  SetPoint, ClearAllPoints, Show, Hide, and SetAttribute in combat, as the
  client does. `/targetexact` picks the nearest mob of that name, so
  same-named mobs can be confused. Verify `/targetlasttarget` after
  `/cleartarget` in client.

### Buff reminders (built)

- One icon per buff (author-approved, instead of the Cooldown Manager's),
  shown only while the buff is missing, with a solid gold border that pulses
  (an Alpha animation, BOUNCE). Arcane Intellect (Arcane Brilliance counts;
  optionally group members who use mana, not warriors or rogues, skipping
  dead, offline, or out-of-sight members; the icon shows the count and its
  tooltip who), Armor (Frost, Ice, or Mage Armor), and Dampen or Amplify
  Magic (off by default). Only buffs you know. Matched by name, so every rank
  counts.
- Clicking an icon casts the missing buff (author-approved): a
  `SecureActionButtonTemplate` button with `type1` spell, `spell1` by name
  (highest rank), and `unit1`. Arcane Intellect goes to you first, then the
  first group member who lacks it and is in range (`C_Spell.IsSpellInRange`
  not false), else the first; as each buff lands (`UNIT_AURA`), the click
  moves to the next. With two or more missing, Arcane Brilliance (known, and
  Arcane Powder 17020 carried) instead. Warriors and rogues are never counted
  or targeted. Armor and Dampen/Amplify recast the last one you cast (saved
  per character in `reminders.last`), else the best known (Mage, Ice, then
  Frost Armor; Dampen, then Amplify). Unlocked icons cast nothing, so
  dragging is safe.
- Aura APIs refuse AddOn code in combat, so MTF reads auras only out of
  combat. Secure icons change only out of combat, so they sit in a holder
  (`MageToolsForeverReminders`) hidden for combat by
  `RegisterStateDriver(holder, "visibility", "[combat] hide; show")`; changes
  asked for in combat wait for `PLAYER_REGEN_ENABLED`. Each icon has its own position and size (50-200%, mouse
  wheel while unlocked, 10% steps), saved per character, and joins the one
  frame lock; `/mtf reset` restores places and sizes (a row, 20 apart).
- Magnetic frames (author-approved, Layout.lua, the same as WTF's): every
  movable MTF frame (the conjure, portal, and Polymorph bars and the buff
  reminders; the shield display drags itself) registers a save function.
  While unlocked, a frame dropped within 24 UIParent units of a spot beside
  another shown frame snaps there, 20 apart, lined up by tops, centers, or
  bottoms (lefts, centers, or rights when stacked), whichever is nearest.
  Frames that far apart and overlapping are snapped; Shift-drag moves the
  group (the others anchored to the dragged frame for the drag; every
  center read before any moves, so the snap applies once), which snaps as
  one. Positions save as centers from UIParent's bottom left; resizing keeps
  the center. A reset in combat says once that MTF frames move back after
  combat.

### Planned (pass 2, agreed)

- Reagent counter (like WTF's shard counter), proc sounds (Clearcasting and
  Forever's new procs, via `AddAuraSound`), and conjure emotes on the next
  hardware input, with flavor and credit.

## Project structure

- Runtime files: MageToolsForever.toc, Commands.lua, Core.lua, Layout.lua, Conjure.lua,
  Portals.lua, Polymorph.lua, Reminders.lua, Shield.lua, Chimes.lua, Options.lua, loaded in that order, plus
  Textures/ShieldArc.tga, Textures/ShieldArcInner.tga, and Textures/ShieldArcInnermost.tga. Shield.lua is the
  shared component above; keep it free of MTF references. Commands parses `/mtf`; Core owns saved settings and
  their defaults, the login banner, class and install checks, slash conflict
  reporting, the hardware-input hooks trade placement waits for, and startup;
  Conjure, Shield, and Chimes own their modules and `/mtf debug_*` commands;
  Options owns the settings pages.
- tests/run.lua holds the Lua 5.1 mock suite. tests/test_*.py cover the release
  helpers in scripts/, including that the committed ShieldArc.tga matches
  scripts/build_arc.py. .github/workflows/ holds CI, opt-in publishing, and the
  approval gate check.
- README.md is the user-facing overview, TESTING.md the verification method,
  source evidence, and in-client checklist, docs/RELEASE_PLAN.md the release
  process, docs/CURSEFORGE_LISTING.md the CurseForge form text, and CHANGELOG.md
  the per-release change list.
- Documentation describes purpose, design, rules, and methodology. Do not add
  dated status reports or test-result logs to the docs; CHANGELOG.md is the
  release record.
- The project uses the MIT License. The public author name is `Dyre` (TOC
  `## Author`, login banner, listings); LICENSE keeps the legal name, John
  Bedworth, and the release builder requires that exact notice.
- The TOC uses `## Category: Mage`; keep it identical to the CurseForge main
  category, because the in-game AddOn list groups by exact text.
- The runtime assets are Textures/ShieldArc.tga, ShieldArcInner.tga, and
  ShieldArcInnermost.tga; regenerate them with scripts/build_arc.py. Add no other runtime assets
  without agreement.
- Git origin: git@github.com:jbedworth/MageToolsForever.git. Inspect Git state
  before acting and preserve user work. Text is LF under .gitattributes.

## Client and API verification

- Target: Forever beta 1.60.1, build 70338 (author now on 70425, same version
  and Interface), Interface 16001, Lua 5.1. Pin source review to
  Gethe/wow-ui-source commit `943764493e6b16d63ded3ab304150d1f05e58b57`. Treat
  target-client documentation and FrameXML as authoritative; Retail and
  Classic examples are references only.
- Do not gate the runtime on client version, build, or Interface. Gate only on
  required APIs and the Mage class.
- The target client has Midnight's secret values and AddOn restrictions. Never
  compare, concatenate, index, or print a value that may be secret: check
  `MTF.IsSecret` first and print with `MTF.Describe`.
- Never register `COMBAT_LOG_EVENT_UNFILTERED`: the client refuses it. Blocked-
  action events name MTF for any blocked call, so react to them only around the
  call that caused them.
- Verified for WTF on this client: your own `UNIT_SPELLCAST_SENT`/`SUCCEEDED`
  stay readable in combat; aura APIs error in combat for AddOn code; `/click`
  does not press AddOn buttons; AddOn chat (SAY, EMOTE) is blocked outside a
  hardware event; trade placement from `TRADE_SHOW` works.
- WoW APIs can return no values rather than nil; store results in locals before
  passing them to `tostring`. The client may not show Lua error popups, so
  diagnostics report errors in chat.
- Prefer `/mtf debug_*` commands over long `/run` scripts. Diagnostics may run
  while MTF is unavailable, read only, and may wrap a step in `pcall` that
  prints the failure in chat.

## Clean coding

- Lua 5.1 syntax and libraries only. Four-space indentation. Prefer local
  variables and functions; share state through the AddOn namespace. Expose
  globals only when WoW requires them (slash commands, saved variables, the
  conjure bar and its secure buttons), prefixed `MageToolsForever` or `MTF`,
  and the shared `ShieldForeverRegistry`.
- Centralize meaningful constants; avoid unexplained magic numbers.
- Comment sparingly: non-obvious intent, API constraints, or tradeoffs.
- Event-driven work only; no polling or idle `OnUpdate` handlers.

## Safety and error reporting

- Validate commands and inputs before changing settings or items. Treat bad
  commands, missing APIs, other classes, and blocked actions as expected
  failures with concise feedback prefixed `MTF:`.
- Never prompt or open popups in combat. Never swallow errors with blanket
  `pcall` handlers or replace the error handler.
- On an unsupported client, another class, or a mixed install, disable the
  AddOn and report the reason once at login.
- Repair saved settings on load so a damaged or older table cannot break MTF.
- Startup is driven by Core at `PLAYER_LOGIN` calling each module's
  initializer; never rely on event handler order between files.

## Testing and documentation

- Run `.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/lua5.1.exe tests/run.lua`
  and the bundled `luac5.1.exe -p` for syntax. Run
  `.tools/python-3.13.7/python.exe -m unittest discover -s tests -p 'test_*.py'`
  and actionlint on workflow changes. Report actual results; never invent them.
- Add focused tests alongside behavior changes. Mocks model secret values as
  values that raise errors on comparison, concatenation, indexing, or printing.
  Mocks cannot prove protected-action rules, secret-value behavior, layout, or
  taint; those need the in-client checks in TESTING.md.
- Keep README usage and compatibility claims aligned with the implementation.

## Releases and collaboration

- Read docs/RELEASE_PLAN.md before packaging or changing release automation.
- Do not create commits, tags, uploads, or releases unless asked.
- Every release needs a `## <version>` section in CHANGELOG.md with player-facing
  changes; the builder puts it at the top of release-notes.md and fails
  without it.
- Package only MageToolsForever.toc, Commands.lua, Core.lua, Layout.lua, Conjure.lua,
  Portals.lua, Polymorph.lua, Reminders.lua, Shield.lua, Chimes.lua, Options.lua, LICENSE, Textures/ShieldArc.tga,
  Textures/ShieldArcInner.tga, and Textures/ShieldArcInnermost.tga under the top-level `MageToolsForever/` folder, named
  `MageToolsForever-<version>-forever.zip`, with the builder's BigWigs-format
  `release.json` (flavor `forever`) attached for WowUp.
- Publishing requires repository variables `ENABLE_GITHUB_RELEASES='true'` and,
  for CurseForge, `ENABLE_CURSEFORGE_UPLOADS='true'`, plus
  `CURSEFORGE_PROJECT_ID`, `CURSEFORGE_GAME_VERSION_ID`, and the `release`
  environment secret `CF_API_TOKEN` (an environment secret, never a repository
  secret). Both publish jobs use the `release` environment with a required
  reviewer; verify the gate with `gate-check.yml` before enabling publishing.
- Action pins are full commit SHAs; review any pin change against the GitHub API.
- Commit messages, when requested: imperative, capitalized subject, at most
  about 50 characters, no ending punctuation; short wrapped body when useful.
