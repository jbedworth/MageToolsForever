# Agent Guidelines

## Project purpose and scope

Mage Tools Forever (MTF) is a World of Warcraft: Forever AddOn: a suite of
quality-of-life tools for Mages, the counterpart of the author's Warlock Tools
Forever (WTF): Conjure, Portals, the Polymorph bar, and Announce. Each tool has
its own switch on the main settings page and its own subpage. Keep this
feature set; do not add speculative features or frameworks without agreement.

### Dyre's Shields Up and Dyre's Buff Reminders (built 1.2.0; author-approved)

- John, for "virality": MTF no longer duplicates the family's stand-alone
  AddOns, it depends on them, so the CurseForge app installs them and players
  meet them on their other classes. Dyre's Shields Up (DSU, `DyresShieldsUp`,
  CurseForge `dyres-shields-up`, project 1751302) draws the shield display;
  Dyre's Buff Reminders (DBR, `DyresBuffReminders`, `dyres-buff-reminders`,
  project 1753804) shows Arcane Intellect, your armor, and Dampen or Amplify
  Magic (DBR adds it, off by default) and plays the cooldown chimes. MTF's
  own copies (Shield.lua, Reminders.lua, Chimes.lua, the crescent textures,
  scripts/build_arc.py) are gone, and so is Dyre's Sounds: MTF plays no sound.
- TOC `## OptionalDeps: DyresShieldsUp, DyresBuffReminders`, so MTF loads
  without them; CurseForge lists both as required dependencies, with
  `dyres-toolkit` (`RELATIONS`). Without one, Core says once at login (after
  the modules start) "Install <AddOn> from CurseForge for <what>.", or
  "Enable <AddOn> in the AddOn list for <what>." when `C_AddOns.GetAddOnInfo`
  says it is installed (its reason is not "MISSING") (`MTF.COMPANIONS`,
  `MTF.CompanionMessage`). Only CurseForge is named.
- Settings are linked, not mirrored: the Shield, Buff Reminders, and Cooldown
  Chimes pages hold only the toolkit's `AddSettingsLink` button ("Open Shield
  settings", "Open Buff Reminders settings"), which opens that AddOn's own
  page, is greyed while it has not joined the toolkit, says the same
  install or enable line when clicked then, and never opens in combat.
- The saved keys `db.shield`, `db.reminders`, and `db.chimes` (MTF 1.1 and
  older) stay exactly as they were, also through unlock, lock, and reset (a
  test checks): DSU copies the shield settings and DBR the reminder switches,
  the group switch, the last armor, Dampen, and the chimes, once per
  character, also when installed later. Reminder icon places start fresh in
  DBR (John). Arcane Powder is counted by DBR's Consumables; the portal bar
  keeps the runes.


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
- Size setting (author-approved): Bar size, 50-150% in steps of 5, default
  100; it applies out of combat (secure buttons).
- Mana gems (author-approved): like WTF's Healthstones without trading.
  Left- and middle-click use your best gem; right-click conjures the best rank
  you do not carry (each rank is unique in your bags). Before a gem rank is
  known (Conjure Mana Agate comes at level 28), the button is desaturated and
  clicks say when it comes; the "! Mana Gem" macro is not written until a rank
  is known.
- Macros live in the character tab with the question-mark icon (134400), are
  rewritten out of combat only when the body changes, leave the last 2
  character slots free, and are deleted when "Keep conjure macros" is turned
  off. Bodies: `#showtooltip`, `/use [btn:2] <rank>`, `/stopmacro [btn:2]`,
  then `/use item:` for every rank, best first. Ranks are cast by exact name,
  "Conjure Water(Rank 3)", from `C_Spell.GetSpellSubtext`.
- Every macro and click macrotext MTF writes casts with `/use`, never `/cast`
  (author: "every character counts"): the pinned SlashCommands.lua `/use`
  uses an item of that exact name, else `CastSpellByName`, and no spell MTF
  names ("Conjure Water(Rank N)", "Conjure Mana Agate", "Polymorph",
  "Polymorph: Pig") is an item name. `/castsequence` stays. Every `@focus`
  condition has `exists` (author). A test checks every body MTF writes.
- `Constants.MacroConsts.MAX_CHARACTER_MACROS` gives the slot limit; the global
  exists only after Blizzard's Macro window loads.
- Secure attributes change only out of combat; changes wait for
  `PLAYER_REGEN_ENABLED`.
- Spell and item IDs are Classic's (confirmed in client for water and food
  ranks 1-3); `/mtf debug_conjure` prints what the client knows. The client
  sends an item's level only once it has the item's data (not for ranks the
  Mage does not carry), so each rank's Classic required level stands in
  until then.

### Dyre's Toolkit widgets (built; author-approved, 2026-10-20)

- Dyre's Toolkit (`src/DyresToolkit`, owned by the coordinator; never edit
  it, ask there) is required, contract 2 (Toolkit 2.0; 2.3 for
  `AddSettingsLink`): TOC `## Dependencies: DyresToolkit` and `## Group:
  DyresToolkit`; CurseForge required dependency `dyres-toolkit`
  (`RELATIONS`). John: all widget layout is centralized in the
  toolkit; MTF was its first client and keeps no layout code of its own
  (no Layout.lua, mover, grid, unlock or grid switches, resize helper, or
  fallback).
- Core's `MTF.Toolkit()` is `DyresToolkit.RequireContract(2)` with the
  functions MTF uses checked. Without it (no toolkit, or an older one) MTF
  stays off at login with one line naming CurseForge
  (`TOOLKIT_MISSING`). After the modules start, `RegisterAddOn` with
  `setLocked` (MTF refreshes its samples and visibility, quietly; the
  toolkit says one line for all and draws the outlines) and `openSettings`.
  `MTF.db.locked` is a copy of the toolkit's lock.
- Every movable frame is a widget (`DyresToolkit.CreateWidget`), with
  `store` = its saved table, so the saved keys carry over unchanged
  (`position` as {point, relativePoint, x, y}, `scale`, and the Polymorph
  bar's own keys):
  - the conjure bar `MageToolsForeverConjure`: mouse "always", content 174 x
    48, Bar size 50-150%; it holds secure buttons, so the toolkit changes it
    only out of combat;
  - the portal bar `MageToolsForeverPortals`: mouse "always", Bar size,
    `SetContentSize` with one button per known spell;
  - the Polymorph holder `MageToolsForeverPolymorph` (secure): mouse "client"
    (MTF's click-through rule), sizes scale (Bar size), width, barHeight
    (saved as "height": the toolkit reserves "height" for a frame height),
    textScale, opacity; `measure` gives the frame size; `onLayout` and
    `onOpacity` lay out the visible bar and rebuild the engine slot.
  Every conjure and portal button is a drag handle of its bar
  (`widget:AddDragHandle(button)`: the buttons cover most of it; clicks
  still reach them).
- The toolkit owns placement, dragging, snapping (also to other AddOns'
  frames), the grid, Shift and Ctrl, the gold outline and hint, resizing
  from the center, waiting out combat for protected widgets, repairing the
  saved numbers, and the size sliders with gold marks and "Reset size"
  (`AddWidgetSettings`, labels "Bar size" and "Bar width"; no label repeats "(%)", since the values show the % sign (John, 1.1.2); the
  Polymorph bar's "Reset size" restores width, bar height, and text size
  only, `spec.resetSizes`, John-approved; Bar size and Opacity stay). MTF never calls SetScale, SetSize, SetPoint,
  StartMoving, or EnableMouse on a widget, except EnableMouse on the
  Polymorph holder (a test wraps those methods and checks).
- `/mtf unlock` and `/mtf lock` call the toolkit's `SetLocked`. `/mtf reset`
  calls `ResetWidgets("MageToolsForever")`.
- Settings: MTF's page is `RegisterSettingsCategory("Mage Tools Forever")`
  under "Dyre's AddOns", its pages under that; `/mtf` opens it through the
  toolkit's `OpenSettings` (never in combat).
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

- Look (author-approved, 1.1.0, after WTF 1.1.0's DoT tracker): Bar width
  (120-400, step 10, default 200), Bar height (the bar line, 10-40, default
  16; the icon is 2 less), and Text size (50-200%, step 5, default 100: a
  share of each font string's own size, read once when it is new; found in
  client: setting the template again did not reset a size set before, so
  each slider step multiplied the label until it was huge)
  (Core's `POLYMORPH_SIZE_SPECS`), and Opacity (10-100%, step 5, default
  100), each slider with a gold default mark (Dyre's Toolkit's widget
  settings, see above), and "Reset size". The defaults draw the old bar
  exactly (name line 18, height 40). "Bar size" is the widget's scale on
  top. The toolkit sizes the secure holder from the center (out of combat);
  its `onLayout` scales and lays out the visible bar (`ApplyLook`) and
  rebuilds the engine slot once, 0.2 s after a slider rests (`BuildBar`: a
  new AuraContainer, the old one `SetUnit("none")` and hidden, bound again
  to the sheep), only when the slot's sizes or opacity changed. The visible
  bar is not the holder's child (a secure parent would stop it showing and
  hiding in combat): it is anchored CENTER to the holder. Opacity: the
  toolkit fades the holder, and `onOpacity` fades the visible bar, at once,
  also in combat.
- Engine-owned objects (family rule, found in WTF): the slot button and what
  MTF hands to it (`SetIcon`, `SetDurationBar`, `SetSpellName`,
  `SetDurationText`) are set up only in `initializeFrame`
  (`SlotInitializer`); any later change from AddOn code raises "Attempt to
  access forbidden object from code tainted by an AddOn". The engine's
  duration bar ignored its parent's opacity in WTF, so MTF's calls
  `SetIgnoreParentAlpha(true)` and carries the opacity in its color and its
  texts, set in `initializeFrame`. The mock refuses every change to handed
  objects after `initializeFrame` (reads still work).
- Click-through (players reported it in 0.3.2): the secure holder is
  invisible, so it takes the mouse only while it holds a sheep to click or
  frames are unlocked (`EnableMouse` in `ApplyClick`, out of combat only;
  after a sheep forgotten in combat, clicks pass through again when combat
  ends). The bar on top never takes the mouse. Every other MTF frame that
  takes the mouse is visible (the conjure and portal bars and their
  buttons).
- One block in WTF's Bars format (author-approved; only one Polymorph of
  yours is up at a time): the mob's name above one bar line, an
  AuraContainer slot (`HARMFUL|PLAYER`, `includeSpellIDs` = Classic Polymorph,
  Pig, Turtle, and Cow IDs plus spellbook spells of those names) that the
  engine draws with `SetDurationBar` (RemainingTime), `SetSpellName`, and
  `SetDurationText`; a dim line behind it shows a broken Polymorph. The bar
  tracks your focus only (John, 1.2.1: "Let the macro set focus and mark the
  sheeped mob. Have the sheep-tracker box depend on it being the 'focus' mob,
  and just resheep it."). At `UNIT_SPELLCAST_SENT`, MTF locks the GUID only
  when the cast is at your focus: the focus's name is the cast's, its GUID
  is readable, and `UnitCanAttack` is readable and true (`LockFocusGUID`).
  Never a match by name on another unit (1.2.1 in client: the moon went to a
  far neutral Chicken and same-named mobs could be confused). On
  `UNIT_SPELLCAST_SUCCEEDED` a locked cast binds the container to "focus".
  It forgets the mob when it dies (`UNIT_HEALTH`, by GUID), when
  PLAYER_FOCUS_CHANGED shows no focus or a readable GUID of another mob (a
  secret focus GUID stays bound), after the longest Polymorph (50 s) plus
  5 s, or on the next Polymorph at your focus. A cast at a mob that is not
  your focus (the plain spell button on your target, mouseover) drives
  nothing. MTF never reads the aura; a resist cannot be seen (the combat log
  is closed), so a successful cast counts as landed.
- On cast start (`UNIT_SPELLCAST_SENT`, author-approved), the group message
  "Sheeping %T; you spank it, you tank it" (the author's classic line, no
  credit), raid or party only, at most once per 3 s; switch and text on the
  Announce page.
- The moon (index 5, author-approved) comes only from secure `/tm` in
  "! Polymorph" (John, 1.2.1: "What does work, 100% of the time, is the
  marking the sheep with the macro"; Blizzard's /tm runs untainted from the
  key press, pinned SlashCommands.lua), also in combat; "!" keeps a second
  press from toggling it off. The bar's click never marks (John: "leave
  target marking out of the resheep-on-click"). The "Mark the sheep with the
  moon" switch (on by default) decides only whether the macro has its /tm
  line; a change rebuilds it out of combat. A plain spell-button Polymorph
  gets no moon. MTF never calls `SetRaidTarget` (family rule): 1.2.1 test
  builds called it from a C_Timer.After(0) callback, on "target" only and
  proven by GUID, and John's BugGrabber still showed ADDON_ACTION_FORBIDDEN
  for it (`/mtf debug_polymorph`: "ADDON_ACTION_FORBIDDEN for target from
  the timer"), while TankHelper's marks work; the rule is unknown, and John
  ended the experiment. Earlier (coordinator, 0.3.3): in John's client, with MTF's
  out-of-combat guard in place, BugGrabber showed "4x
  [ADDON_ACTION_FORBIDDEN] AddOn 'MageToolsForever' tried to call the
  protected function 'SetRaidTarget()'" (Polymorph.lua Mark <-
  OnCastSucceeded <- the event handler), and the taint log "An action was
  blocked because of taint from MageToolsForever - SetRaidTarget()". In 0.3.2
  players saw the "blocked from an action" popup. The exact rule is unknown
  (TankHelper's direct call on an unmarked TARGET from a C_Timer callback
  works for John); do not work around it. The mock forbids `SetRaidTarget`
  always, and a test checks MTF never calls it and no runtime file contains
  a `SetRaidTarget(` call.
- "! Polymorph" (author-approved, after the author's own, `polymorph.macro`):
  once you know Polymorph, `#showtooltip`, `/focus [@mouseover,harm,nodead]
  [nocombat,harm,nodead]`, `/tm [@focus,harm,nodead,exists] !5` (author's
  line, exactly), `/use [@focus,exists,harm,nodead] Polymorph`. The "!" keeps a
  second press from toggling the moon off. A body change is written out of
  combat (`WriteMacro` edits a macro whose body differs), so older copies
  update. The macro text is John's, exactly (1.2.1). Known gap: the
  mouseover clause is true on an attackable neutral critter, so the mouse on
  a Chicken focuses and marks it; macro conditions cannot exclude critters.
- Click to re-sheep (author-approved; John, 1.2.1: "no /tm, no targeting, no
  mouseover"): the bar sits on a secure button (`MageToolsForeverPolymorph`,
  the drag anchor); the visible bar is an ordinary frame anchored to it, so
  it shows and hides in combat. The macro is `/use [@focus,exists,harm,nodead]
  <the Polymorph you cast>`, set while a sheep is up. Attributes change only
  out of combat: the click is set as a cast at your focus starts (a pull's
  Polymorph starts before combat); another Polymorph spell begun in combat
  updates it when combat ends. A cast that fails out of combat gives the
  click back to the sheep that is up, or clears it. The holder (and the bar
  with it) is scaled only out of combat too: in client, a recast from the
  bar that landed in combat rescaled the secure holder, and every click
  after failed. Tests make secure frames refuse SetScale, SetPoint,
  ClearAllPoints, Show, Hide, and SetAttribute in combat, as the client
  does.

### Planned (pass 2, agreed)

- Conjure emotes on the next hardware input, with flavor and credit. (Proc
  sounds are DBR's, and Arcane Powder is counted by DBR's Consumables.)

### Resizing (built; author's rule, 1.1.0)

- Every MTF frame resizes from its center: the toolkit's widgets do it
  (`DyresToolkit.ResizeFromCenter`). Found in client: a frame placed by an
  offset from a screen corner moved right and up as it grew, because the
  offset scales with the frame.

## Project structure

- Runtime files: MageToolsForever.toc, Commands.lua, Core.lua, Conjure.lua,
  Portals.lua, Polymorph.lua, Options.lua, loaded in that order; no media.
  Commands parses `/mtf`; Core owns saved settings and their defaults, the
  Dyre's Toolkit link, the companion AddOns' lines, the login banner, class
  and install checks, slash conflict reporting, the hardware-input hooks
  trade placement waits for, and startup; Conjure, Portals, and Polymorph own
  their modules and `/mtf debug_*` commands; Options owns the settings pages.
- tests/run.lua holds the Lua 5.1 mock suite. It loads Dyre's Toolkit's real
  Core, Layout, Widgets, and Settings files from a copy in tests/toolkit (CI
  has only this repository); a test fails when that copy differs from
  ../DyresToolkit, so copy the toolkit's files again after it changes.
  tests/test_*.py cover the release helpers in scripts/. .github/workflows/
  holds CI, opt-in publishing, and the approval gate check.
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
- The TOC uses `## Group: DyresToolkit`, so the in-game AddOn list nests MTF
  under Dyre's Toolkit (the family groups there). `## Category: Mage` stays
  identical to the CurseForge main category.
- MTF ships no runtime assets (no textures, no sounds). Add none without
  agreement.
- Git origin: git@github.com:jbedworth/MageToolsForever.git. Inspect Git state
  before acting and preserve user work. Text is LF under .gitattributes.

## Client and API verification

- Target: Forever beta 1.60.1, build 70450 (tested in client), Interface
  16001, Lua 5.1. Pin source review to Gethe/wow-ui-source commit
  `943764493e6b16d63ded3ab304150d1f05e58b57` (the 70338 source; the client
  was tested on 70450, same version and Interface). Treat
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
  conjure bar and its secure buttons), prefixed `MageToolsForever` or `MTF`.
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
- Package only MageToolsForever.toc, Commands.lua, Core.lua, Conjure.lua,
  Portals.lua, Polymorph.lua, Options.lua, and LICENSE under the top-level
  `MageToolsForever/` folder, named
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
