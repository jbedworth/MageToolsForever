# Testing

## Method

1. **Pinned source review.** Client behavior is read from Blizzard's FrameXML
   and generated API documentation at Gethe/wow-ui-source commit
   `943764493e6b16d63ded3ab304150d1f05e58b57` (`1.60.1.70338`; the client was tested on build 70450). Source
   establishes declared APIs, templates, and code paths, not operational behavior.
2. **Automated mock tests.** `tests/run.lua` exercises commands, saved settings,
   the conjure buttons, trades, and macros, the shield display, the chimes, and
   the settings pages against a minimal mock of the client. Mocks model secret
   values as values that raise errors on comparison, concatenation, indexing,
   or printing. The suite loads Dyre's Toolkit's real files from
   ../DyresToolkit when that folder is there, else the copy in tests/toolkit
   (CI); its first line says which. No test compares shared files byte for
   byte.
3. **In-client checks.** The checklist below covers everything mocks cannot.

```sh
.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/lua5.1.exe tests/run.lua
.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/luac5.1.exe -p Commands.lua Core.lua Conjure.lua Portals.lua Options.lua tests/run.lua
.tools/python-3.13.7/python.exe -m unittest discover -s tests -p 'test_*.py'
```

Tooling: portable Lua 5.1 (LuaRocks 3.13.0 Windows bundle) and the official
python.org 3.13.7 embeddable archive under the ignored `.tools/` folder; CI uses
ubuntu-24.04's `lua5.1` package and native `python3`.

## Source findings

- `C_Item.GetItemCount` and the `C_Container` item APIs carry no secret flags.
- `/mtf debug_conjure` on a level ~25 Mage: Conjure Water and Conjure Food
  ranks 1-3 use Classic's spell IDs (5504-5506, 587/597/990) with "(Rank N)"
  names; Purified Water (2136) and Rye (1114) need level 15. Items not
  carried had no item data (no name, no level), so MTF falls back to
  Classic's required levels. A Food & Water trade placed both stacks.
- A stack split into an empty bag slot at the click was not yet filled when
  the trade window opened; waiting for the slot to settle (empty, other item,
  or locked; `ITEM_LOCK_CHANGED` and `BAG_UPDATE_DELAYED`, up to 5 s) placed
  the share with no click.
- In client, a stack split onto the cursor and dropped into a trade slot
  traded the whole source stack (a share of 10 gave 20): the trade window
  holds bag slots. MTF now splits into an empty bag slot first.
- Verified for WTF on this client and assumed here: own cast events stay
  readable in combat; aura APIs error in combat for AddOn code; `/click` does
  not press AddOn buttons; trade placement from `TRADE_SHOW` works; macros need
  `Constants.MacroConsts.MAX_CHARACTER_MACROS`.

### Open client questions

1. Forever's mana gem IDs (Conjure Mana Agate at level 28) and higher conjure
   ranks.

## In-client checklist

- [ ] `/mtf` opens Options > AddOns > Mage Tools Forever; each subpage opens.
- [ ] The login banner shows the version and Dyre; another class gets one
      message and no settings.
- [ ] No target: water and food left-click drink and eat your best (out of
      combat); right-click conjures your best rank.
- [ ] Target a lower-level party member: right-click conjures the rank they can
      use; left-click splits the share into an empty bag slot and opens a trade
      with exactly the share size as one stack (not the whole stack); with
      only smaller stacks, they are merged into one; with less, all of it;
      with full bags and a big and a small stack, the small one is topped up
      (no free slot needed); with full bags and only a big stack, the "free
      one bag slot" message. Then Food in the same trade
      adds the bread, with its own whisper. The player gets one whisper as the trade
      opens. With none they can use, the "conjure some first" message.
- [ ] Let another player open a trade with you, with no one targeted: the
      buttons match their level, and left-click puts the share straight into
      the open window, with the whisper.
- [ ] Food & Water: with a friend targeted, one left-click trades 10 water and
      10 food with one whisper; untargeted, it eats and drinks at once;
      right-click conjures water, then food, on the next click.
- [ ] Bar size at 60% shrinks the conjure bar; a change in combat applies
      after combat.
- [ ] Middle-click eats or drinks your own best with someone targeted.
- [ ] Shift + left-click on Water, Food, and Food & Water eats or drinks with a
      party member targeted, and opens no trade.
- [ ] With **Trade only with Shift-click** on: left-click drinks with a party
      member targeted; Shift + left-click trades the share; Ctrl + Shift +
      left-click drinks and opens no trade. The tooltip lines follow the setting.
- [ ] Below level 28 the gem button is greyed out and says level 28; no
      "! Mana Gem" macro.
- [ ] "! Water" and "! Food" appear in your character macros; left-click uses,
      right-click conjures, also as a keybind.
- [ ] Portal bar: one button per known teleport and portal, teleports first,
      each with its rune count; a teleport or portal casts with zero runes
      (legacy talents); a portal in a party or raid sends the group message
      once, nothing when alone; a teleport emotes at the first key press or
      click after the loading screen; a spell learned in combat joins after combat;
      `/mtf debug_portals` lists the IDs (check Forever's IDs match Classic's).
- [ ] Every MTF macro (Water, Food, Food & Water, Mana Gem) reads `/use`,
      not `/cast`; right-click of each conjure macro still conjures the shown
      rank (`/use` casts a spell by name).
- [ ] Bar size on the Conjure and Portals pages: the bar grows and shrinks
      around its middle and does not move, also for the portal bar when you
      learn a new teleport or portal. Each Bar size slider has a gold mark at
      100, and its name has no "(%)". Settings survive `/reload`.
- [ ] The conjure and portal bars snap to each other; a Shift-dragged group
      keeps its spacing when it snaps.
- [ ] Announce page: switches and texts save, Enter keeps, Escape undoes,
      Defaults restores, the page scrolls, and each whisper uses its text.
- [ ] Dyre's Toolkit 2.0 widgets (MTF 1.1.0): MTF is listed under Dyre's
      Toolkit in the AddOn list; MTF's page is under Options > AddOns >
      Dyre's AddOns, with Conjure, Portals, Polymorph, Shield, Buff
      Reminders, Cooldown Chimes, and Announce under it (Polymorph is a link
      page since 1.6.0); `/mtf` opens it
      (and says out of combat in combat). Every frame is where it was before
      the update, at the same size (conjure and portal bars). `/mtf unlock`, `/dyre
      unlock`, the minimap button, and the toolkit's "Unlock frames" switch
      outline MTF's frames and the other Dyre's AddOns' with one "Dyre:"
      line and no "MTF:" line, each outline with its name in the hint; the
      toolkit's grid shows. The conjure and portal bars drag from any of
      their buttons; their buttons still click while locked. A dropped MTF bar snaps beside another Dyre's AddOn's frame; with "Snap
      to the grid" on, a bar dropped alone centers on a grid point;
      Shift-drag moves a snapped group. In combat, unlock and drag: secure
      frames wait for the end of combat, with no "blocked" popup and no
      BugGrabber entry. `/mtf reset` puts every MTF frame back (after
      combat if needed). Positions and sizes survive `/reload`.
- [ ] With Dyre's Toolkit 2.4 or older, or without it: MTF says once at
      login that it needs Dyre's Toolkit 2.5 or later from CurseForge, and
      stays off with no errors.
- [ ] Polymorph moved to Dyre's Debuff Tracker (1.6.0): on a Mage that had
      the Polymorph bar on, with Dyre's Debuff Tracker installed, the first
      login shows one line about it, Dyre's Debuff Tracker's "Copied your
      Polymorph bar settings from Mage Tools Forever ...", and no MTF line.
      Dyre's Debuff Tracker shows one Polymorph bar with the MTF place, sizes,
      opacity, and moon setting, keeps "! Polymorph" in the same action bar
      slot, and sends one group message per cast with the MTF text.
      MTF draws no Polymorph bar and writes no "! Polymorph". `/mtf
      debug_polymorph`, `/mtf debug_focus`, and `/mtf reset_focus` show the
      usage. MTF's Polymorph page has one button, "Open Debuff Tracker
      settings", that opens Dyre's Debuff Tracker's page (not in combat).
- [ ] Without Dyre's Debuff Tracker: one line at login, "Install Dyre's
      Debuff Tracker from CurseForge for the Polymorph bar.", and no other
      MTF line about the Polymorph bar; the Polymorph
      page's button is greyed and says the same; Conjure and Portals work.
- [ ] Dyre's Shields Up and Dyre's Buff Reminders (MTF 1.2.0): with both
      enabled, no "Install" or "Enable" line at login. A Mage with MTF 1.1
      shield, reminder, and chime settings gets them in Dyre's Shields Up and
      Dyre's Buff Reminders once (the shield's size, place, number, and
      break sound; the reminder switches, the group switch, the last armor,
      Dampen; every chime), and they do not change on a later `/reload`.
      MTF draws no shield ring, shows no reminder icons, and plays no chime
      of its own; you see one shield ring and hear each chime once.
- [ ] MTF's Shield, Buff Reminders, and Cooldown Chimes pages each have one
      button ("Open Shield settings", "Open Buff Reminders settings") that
      opens that AddOn's own page; in combat it says the settings open out
      of combat. `/mtf debug_shield`, `debug_chimes`, and `debug_reminders`
      show the usage.
- [ ] With Dyre's Shields Up disabled in the AddOn list: one line at login,
      "Enable Dyre's Shields Up in the AddOn list for the shield display.";
      the Shield page's button is greyed and says the same; Conjure and
      Portals work. With it uninstalled, the line says
      "Install Dyre's Shields Up from CurseForge for the shield display."
      The same for Dyre's Buff Reminders ("buff reminders and cooldown
      chimes").
- [ ] Settings survive `/reload` and stay separate on a second Mage.
- [ ] Profile (Toolkit 2.10.0 or newer): on a second Mage, change the share
      size, a bar's place and size, and a message; log out. On the first
      Mage, Dyre's AddOns > Profile > Copy settings from the second Mage >
      Copy: the bars move and resize at once, the Announce page shows the new
      text, and no reload is asked for. The
      first Mage's MTF macros stay. In combat, Copy is refused. Export
      profile, change a setting, Import profile with that line: the setting
      comes back. "Defaults" puts every MTF setting back to its default.
