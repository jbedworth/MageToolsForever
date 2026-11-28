# Agent Guidelines

## Project purpose and scope

Mage Tools Forever (MTF) is a World of Warcraft: Forever AddOn: a suite of
quality-of-life tools for Mages, the counterpart of the author's Warlock Tools
Forever (WTF): Conjure, Portals, and Announce. Each tool has
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
- Proc overlays (Missile Barrage, Fingers of Frost; John, 2026-11-18: "DSU is
  the right home for our 'spell activation overlays'") are DSU's, never MTF's.
- TOC `## OptionalDeps: DyresToolkit, DyresShieldsUp, DyresBuffReminders, DyresDebuffTracker`
  (family rule: no `## Dependencies`), so MTF loads without them; CurseForge lists them as required dependencies, with
  `dyres-toolkit` (`RELATIONS`). Without one, Core says once at login (after
  the modules start) "Install <AddOn> from CurseForge for <what>.", or
  "Enable <AddOn> in the AddOn list for <what>." when `C_AddOns.GetAddOnInfo`
  says it is installed (its reason is not "MISSING") (`MTF.COMPANIONS`,
  `MTF.CompanionMessage`). Only CurseForge is named.
- Settings pass through (John, 2026-11-26: MTF "should surface every setting
  in the wrapped addon's settings, and just pass-through the setting to the
  wrapped addon"; it replaces the 2026-10-22 "linked, not mirrored" rule).
  Options.lua `AddCompanionPage`: with Dyre's Toolkit 2.17.0's
  `AddSettingsSection` (feature test), each companion page asks for the
  owner's section, `{addon, key, host = "MageToolsForever", link}`: Shield
  (DyresShieldsUp, "shield"), Reminders (DyresBuffReminders,
  "reminders"), Chimes (DyresBuffReminders, "chimes"), Procs
  (DyresBuffReminders, "procs"; John, 2026-11-27: "mage proc arcs from DBR
  are not in MTF, we should add a Procs panel"; no filter, DBR shows the
  class's procs: Missile Barrage, Fingers of Frost, Clearcasting; its section
  needs Toolkit `SETTINGS_SECTIONS_VERSION` 2, else the link; after it, on
  the same page, DyresDebuffTracker "cues", Winter's Chill), Polymorph
  (DyresDebuffTracker, "control"). One name per section (John, 2026-11-27:
  "let's have the same name used consistently everywhere"): each companion
  page and its link take the owner's title (`SettingsSectionTitle`), which is
  also the owner's own heading and its switch's label on MTF's top page; a
  page with two sections takes the first's. While the owner is missing, the
  same words: Shield display, Reminders, Chimes, Procs, Debuff Cues, Crowd Control
  (the Polymorph page before; DDT names its sections so).
  MTF's own pages keep their names (Conjure, Portals, Announce). The owner's rows read and write its own
  live settings; MTF saves none of them. Without the owner's section (not
  loaded, older, or its build fails), the Toolkit draws `link` instead; with
  an older Toolkit, MTF calls `AddSettingsLink` with the same link as before.
  The link button ("Open Shield settings", "Open Buff Reminders settings",
  "Open Debuff Tracker settings") opens that AddOn's own page, is greyed
  while it has not joined the toolkit, says the same install or enable line
  when clicked then, and never opens in combat. The minimum Toolkit stays 2.5.
- Primer (John, 2026-11-27: "add a primer-text to tell people what they get
  if they install it"): each page passes `primer`, `MTF.COMPANION_PRIMERS[key]`,
  what that AddOn adds for a Mage, ending "Install <AddOn> from CurseForge."
  (at most 400 characters, the Toolkit's `SETTINGS_PRIMER_MAX`; a test checks).
  The Toolkit shows it in a box over the greyed link only while the AddOn is
  not loaded. Passed only when the Toolkit has `AddSettingsPrimer`.
- Top switches and greying (John, 2026-11-27: "when the top-level is off, the
  settings that are controlling a disabled feature should be disabled too.
  Also, the top-level disable for each section should be on the top-level MTF
  panel."). With Toolkit `SETTINGS_SECTIONS_VERSION` 3 or later, MTF's top
  page has, after "Conjure bar" and "Portal bar", each companion's top switch
  (`part = "master"`, `COMPANION_MASTERS`, in the sub-page order: shield,
  reminders, chimes, procs, control), with the owner's labels; with the owner
  missing the Toolkit adds none. Each sub-page then asks for `part = "rest"`
  (greyed by the owner while its switch is off), with the link and primer as
  before. Below version 3, no `part`: each page has the whole section.
  MTF's own rows: on the Conjure page, "Share stack size", "Trade only with
  Shift-click", "Layout", and the bar's size rows are greyed while "Conjure bar" is
  off; "Keep conjure macros" is not, because the macros work without the bar
  (`UpdateMacros` does not read `conjure.enabled`). On the Portals page,
  "Layout" and the size rows are greyed while "Portal bar" is off. Size rows use
  `AddWidgetSettings` `opts.modify` (Toolkit 2.17.0; an older one ignores
  it). The Announce page (a canvas page) is not greyed.
- Tooltips (John, 2026-11-27: "every one of the tooltips seems to start with
  a good one sentence description, but then has nonsensical follow-on text
  that is clearly not meant for users to see"): one plain sentence that says
  what the setting does or what the player sees. No how-to tips,
  cross-references to other pages, combat timing, defaults, or history. A
  short second sentence only when the player loses something without it
  ("Keep conjure macros": "Turning this off deletes them."). The conjure
  buttons' tooltips list only what each click does (no macro hint). A test
  checks every tooltip MTF writes.
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
    full name; default texts name no AddOn (1.8.1; John, 2026-11-28: a player
    uninstalled WTF over messages that "advertised the addon", and "Tone
    down the flair a bit too"). A saved text equal to an earlier default
    becomes the new one (`OLD_ANNOUNCE_DEFAULTS` in Core); a player's own
    text stays. Water, Food, and Food & Water each
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
  - Shift + left-click (author-approved, 2026-11-17; a player report: in
    dungeons a healer or tank target turned each drink after a pull into a
    trade): `shift-type1` holds the eat or drink action, so it eats or drinks
    your own best, whatever the target. "Trade only with Shift-click"
    (`conjure.shiftTrade`, off by default, in the profile) swaps them: with
    a friendly player targeted, `type1` eats or drinks and Shift + left-click
    trades (PostClick, only with Shift alone held: Ctrl or Alt with Shift
    falls back to `type1`, which drinks, so it must not also trade); the
    trade's `shift-type1` is "" (Blizzard's ATTRIBUTE_NOOP, SecureTemplates.lua),
    so the trade click does not fall back to the drink. Untargeted, the
    Shift attributes are cleared and Shift falls back to left-click. Food &
    Water works the same way. Tooltips list the left- and Shift-click lines
    in the order the setting gives.
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
- Layout (1.8.0; a CurseForge player asked: "Is it possible to add an
  option to change the portal and conjure bars from horizontal to
  vertical?"; John, 2026-11-27: "Yes, Toolkit feature"): Dyre's Toolkit
  2.18.0's button bars, feature-tested with `BAR_LAYOUT_VERSION` >= 1
  (`MTF.HasBarLayout`). The bars call `widget:LayoutButtons(buttons, {size,
  gap, padding})` (the conjure bar its four buttons in order,
  `MTF.LayoutConjureBar`; the portal bar only the shown ones, at each
  `ApplySpells`), with no anchor, so the bar keeps its center on a switch.
  The Toolkit moves the secure buttons only out of combat. "Layout" on each
  page is `AddBarLayoutSetting` (Horizontal or Vertical), greyed while that
  bar's switch on the top page is off (`modify`). Saved as the widget
  store's `orientation` ("vertical", else nil) in `conjure` and `portals`;
  `SanitizeDB` keeps it, so it is in the profile, and `ApplyProfile` lays
  the conjure bar out again (`ReapplyWidgets` does not). With an older
  Toolkit: no Layout row, and MTF places the buttons as a row, as before
  (the saved choice stays). A button's tooltip goes over a row, and beside
  a column on the side of the screen with more room
  (`MTF.BarTooltipAnchor`). Nothing else depends on the layout: the bars
  have no menus or flyouts, the Food & Water icon is split inside its
  button, and the unlocked outline follows the bar's size.
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
  names ("Conjure Water(Rank N)", "Conjure Mana Agate") is an item name.
  `/castsequence` stays. Every `@focus` clause tests the unit with `harm`,
  `noharm`, or `dead` (John, 2026-11-12: "exists is a no-op, drop it"). A
  test checks every body MTF writes.
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
  it, ask there) is required, contract 2, version 2.5 or later (2.3 for
  `AddSettingsLink`, 2.5 for `NoteFocusWorks`; MTF 1.3.0 to 1.5 also used
  2.5's control engine for the Polymorph bar):
  TOC `## OptionalDeps: DyresToolkit` (lead, 2026-11-01) and `## Group:
  DyresToolkit`; CurseForge required dependency `dyres-toolkit`
  (`RELATIONS`). John: all widget layout is centralized in the
  toolkit; MTF was its first client and keeps no layout code of its own
  (no Layout.lua, mover, grid, unlock or grid switches, resize helper, or
  fallback).
- Core's `MTF.Toolkit()` is `DyresToolkit.RequireContract(2)` with the
  functions MTF uses checked (the contract stays 2). Without it (no toolkit, or an older one) MTF stays off
  at login with one line, "needs Dyre's Toolkit: install or update it", naming only
  CurseForge (`TOOLKIT_MISSING`). After the modules start, `RegisterAddOn` with
  `setLocked` (MTF refreshes its samples and visibility, quietly; the
  toolkit says one line for all and draws the outlines) and `openSettings`.
  `MTF.db.locked` is a copy of the toolkit's lock.
- Every movable frame is a widget (`DyresToolkit.CreateWidget`), with
  `store` = its saved table, so the saved keys carry over unchanged
  (`position` as {point, relativePoint, x, y}, `scale`):
  - the conjure bar `MageToolsForeverConjure`: mouse "always", content 174 x
    48 (48 x 174 vertical, `LayoutButtons`), Bar size 50-150%; it holds
    secure buttons, so the toolkit changes it only out of combat;
  - the portal bar `MageToolsForeverPortals`: mouse "always", Bar size,
    `SetContentSize` with one button per known spell, in its layout;
  Every conjure and portal button is a drag handle of its bar
  (`widget:AddDragHandle(button)`: the buttons cover most of it; clicks
  still reach them).
- The toolkit owns placement, dragging, snapping (also to other AddOns'
  frames), the grid, Shift and Ctrl, the gold outline and hint, resizing
  from the center, waiting out combat for protected widgets, repairing the
  saved numbers, and the size sliders with gold marks and "Reset size"
  (`AddWidgetSettings`, labels "Bar size" and "Bar width"; no label repeats "(%)", since the values show the % sign (John, 1.1.2)). MTF never calls SetScale, SetSize, SetPoint,
  StartMoving, or EnableMouse on a widget.
- `/mtf unlock` and `/mtf lock` call the toolkit's `SetLocked`. `/mtf reset`
  calls `ResetWidgets("MageToolsForever")`.
- Profile (Toolkit 2.10.0; John, 2026-11-17: "one place to go to persist
  your profile"): at login, before the modules build their frames, Core
  calls `RegisterProfilePart{addon, title, current = MTF.db, sanitize =
  MTF.SanitizeDB, characterKeys, refresh = MTF.ApplyProfile}`, only when the
  toolkit has it (an older toolkit: nothing changes; the minimum stays 2.5).
  In the profile: `conjure`, `portals` (switches, places, scales, sizes),
  and `announce`.
  `characterKeys` (never copied, exported, or imported): `locked` (a copy of
  the toolkit's account-wide lock, set again at login), `ownedMacros` (the
  macros MTF keeps on this character; macros are per character), and
  `shield`, `reminders`, `chimes` (MTF 1.1 data that Dyre's Shields Up and
  Dyre's Buff Reminders copy once per character), and `polymorph` (MTF 1.5
  data that Dyre's Debuff Tracker reads once). `announce.polymorphGroup` and
  `polymorphGroupText` sit inside `announce`, so they are in the profile:
  a copy or the Defaults can change or drop them before Dyre's Debuff
  Tracker reads them (an accepted gap: it reads them at its first login). MageToolsForeverAccountDB
  is account-wide, so it is not in the profile (John: "user-centric, not per
  character"). The engine writes the part into MTF.db in place, so widgets'
  stores keep their tables.
  `MTF.ApplyProfile` applies it live (copies are refused in combat):
  `ReapplyWidgets` (place, scale), the conjure macros and bar, the portal
  bar, and the Announce page when it is open. No part needs a reload.
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
- A teleport you cast emotes (author-approved, on by default; "teleports to
  %D."; `%D` the teleport's city, `%T` your name, `%Z` your zone when sent:
  after the loading screen, the destination). Emotes are blocked
  outside a hardware event, so it is sent at your next key press or click
  within 60 s of the cast (after the loading screen), as WTF's emotes.

### Announce (built)

- A canvas settings page, as WTF's: a switch and a three-line, one-chat-line
  edit box per message (water, food, and Food & Water trade whispers; the
  portal group message and the teleport emote, `%D` the city, `%Z` your zone
  when the emote is sent). Enter or focus loss keeps an edit
  (newlines become spaces; empty or over 255 bytes is the default), Escape
  undoes, and the panel's Defaults restores the page. The old single
  `conjure.whisper` switch carries over to the three whisper switches.

### Polymorph bar (moved to Dyre's Debuff Tracker, 1.6.0)

- John, 2026-11-20: "Yes, move it" (the lead's wave with WTF's DoT tracker
  and crowd-control bar: a feature's settings and effect live in one
  AddOn). MTF 1.3.0 to 1.5 drew the bar through Dyre's Toolkit's control
  engine (`CreateControlTracker`) at priority 10; Polymorph.lua, its widget,
  settings rows, Announce row, and `/mtf debug_polymorph`, `debug_focus`,
  and `reset_focus` are gone. Dyre's Debuff Tracker's control engine
  (priority 5; `/ddt reset_focus`) now draws the bar, keeps "! Polymorph",
  and sends the group message.
- Saved data stays exactly as MTF 1.5 saved it, for Dyre's Debuff Tracker to
  read once (it never writes them; never rename or delete them):
  `MageToolsForeverDB.polymorph` = {enabled, position {point, relativePoint,
  x, y}, scale, mark, macro, opacity, width, height (the bar line; the
  widget's "barHeight"), textScale}; `MageToolsForeverDB.announce.
  polymorphGroup` (boolean) and `polymorphGroupText` (string); the macro
  name "! Polymorph", recorded in `MageToolsForeverDB.ownedMacros`. MTF had
  no key binding for it. `SanitizeDB` keeps `polymorph` only when it is a
  table and the two announce keys only with their types, and repairs
  nothing. `polymorph` is a profile characterKey. Dyre's Debuff Tracker
  imports only from MTF 1.6.0 or later (it waits while an older MTF is
  loaded), and adopts "! Polymorph" in place, so MTF never deletes it.
- One line about the move, never two (lead, 2026-11-20): with Dyre's Debuff
  Tracker loaded, its own "Copied your Polymorph bar settings ..." line and
  nothing from MTF; without it, only MTF's companion install (or enable)
  line.
- Dyre's Debuff Tracker is a companion (`MTF.COMPANIONS`, `MTF.DEBUFF_TRACKER`):
  TOC OptionalDeps, the CurseForge required relation `dyres-debuff-tracker`
  (project 1777574), the once-per-login install or enable line, and the
  Crowd Control settings page (DDT's "control" section, or its link, "Open Debuff
  Tracker settings"; see the settings rule above).
- MTF 1.2.3's `MageToolsForeverAccountDB.focusWorks` is still carried to the
  Toolkit once at login (`NoteFocusWorks`) and then cleared.

### Planned (pass 2, agreed)

- Conjure emotes on the next hardware input, naming no AddOn. (Proc
  sounds are DBR's, and Arcane Powder is counted by DBR's Consumables.)

### Resizing (built; author's rule, 1.1.0)

- Every MTF frame resizes from its center: the toolkit's widgets do it
  (`DyresToolkit.ResizeFromCenter`). Found in client: a frame placed by an
  offset from a screen corner moved right and up as it grew, because the
  offset scales with the frame.

## Project structure

- Runtime files: MageToolsForever.toc, Commands.lua, Core.lua, Conjure.lua,
  Portals.lua, Options.lua, loaded in that order; no media.
  Commands parses `/mtf`; Core owns saved settings and their defaults, the
  Dyre's Toolkit link, the companion AddOns' lines, the login banner, class
  and install checks, slash conflict reporting, the hardware-input hooks
  trade placement waits for, and startup; Conjure and Portals own
  their modules and `/mtf debug_*` commands; Options owns the settings pages.
- tests/run.lua holds the Lua 5.1 mock suite. It loads Dyre's Toolkit's real
  files (Core, Layout, Widgets, Settings, Profiles, Auras, Units, HealthBars,
  Spells, Macros, Announce, ClassData, Owners, Control) from ../DyresToolkit
  when that folder is there, else from the copy in tests/toolkit (CI has
  only this repository); its first line says which. No test compares shared files
  byte for byte (John: "that's a stupid thing to test for a shared
  resource"); refresh the copy when a toolkit change matters to CI.
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
- Package only MageToolsForever.toc, Commands.lua, Core.lua, Conjure.lua, Portals.lua, Options.lua, and LICENSE under the top-level
  `MageToolsForever/` folder, named
  `MageToolsForever-<version>-forever.zip`, with the builder's BigWigs-format
  `release.json` (flavor `forever`) attached for WowUp. The TOC has
  `## SavedVariables: MageToolsForeverAccountDB` (MTF 1.2.3's focus flag, carried over once) and
  `## SavedVariablesPerCharacter: MageToolsForeverDB`.
- Publishing requires repository variables `ENABLE_GITHUB_RELEASES='true'` and,
  for CurseForge, `ENABLE_CURSEFORGE_UPLOADS='true'`, plus
  `CURSEFORGE_PROJECT_ID`, `CURSEFORGE_GAME_VERSION_ID`, and the `release`
  environment secret `CF_API_TOKEN` (an environment secret, never a repository
  secret). Both publish jobs use the `release` environment with a required
  reviewer; verify the gate with `gate-check.yml` before enabling publishing.
- Action pins are full commit SHAs; review any pin change against the GitHub API.
- Commit messages, when requested: imperative, capitalized subject, at most
  about 50 characters, no ending punctuation; short wrapped body when useful.
