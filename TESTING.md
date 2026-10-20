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
   or printing.
3. **In-client checks.** The checklist below covers everything mocks cannot.

```sh
.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/lua5.1.exe tests/run.lua
.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/luac5.1.exe -p Commands.lua Core.lua Layout.lua Conjure.lua Portals.lua Polymorph.lua Reminders.lua Shield.lua Chimes.lua Options.lua tests/run.lua
.tools/python-3.13.7/python.exe -m unittest discover -s tests -p 'test_*.py'
```

Tooling: portable Lua 5.1 (LuaRocks 3.13.0 Windows bundle) and the official
python.org 3.13.7 embeddable archive under the ignored `.tools/` folder; CI uses
ubuntu-24.04's `lua5.1` package and native `python3`.

## Source findings

- `UnitGetTotalAbsorbs` has `SecretReturns = true` (always secret);
  `UnitHealthMax` has `SecretWhenUnitHealthMaxRestricted`. `UNIT_ABSORB_AMOUNT_CHANGED`
  carries the unit. `StatusBar:SetValue`, `SetMinMaxValues`, and
  `SetStatusBarColor`, `FontString:SetText`, `Region:SetAlpha` (adding the
  Alpha secret aspect), and `AbbreviateNumbers` declare
  `SecretArguments = "AllowedWhenTainted"`, read here as accepting secrets from
  AddOn code; `SetShown`, `StatusBar:SetTimerDuration`, and curve objects'
  `Evaluate` (`AllowedWhenUntainted`) do not.
- `C_Spell.GetSpellCooldown` has `SecretWhenCooldownsRestricted`; in its
  result only `isEnabled`, `isActive`, and `isOnGCD` are never secret. No event
  fires when a cooldown ends. `C_Secrets.GetSpellCooldownSecrecy` reports a
  spell's cooldown secrecy (printed by `/mtf debug_chimes`).
- `C_Item.GetItemCount` and the `C_Container` item APIs carry no secret flags.
- Every sound comes from the library AddOn Dyre's Sounds (its own suite and
  TESTING.md cover the catalog and the menu); MTF's mocks fake it with a few
  sounds of each kind, and leave it out to test the missing-library path.
- AuraContainer `includeSpellIDs` is a set, `{[spellID] = true}`
  (Blizzard_CustomAuraContainer.lua: "Map of permitted spell IDs"); a list
  matched nothing in client, so no shield icon showed. With the set, Mana Shield's inner
  crescent (draining with time) and the shield icons showed, nested with Fire
  Ward's outer crescent (draining with absorption).
- Forever's shield buffs carry Classic IDs (Mana Shield 1463, Fire Ward 543).
  Fire Ward's aura points (164) matched `UnitGetTotalAbsorbs`; Mana Shield's
  buff has no points and is not in the total. The AuraContainer icons'
  `IsShown` is secret to AddOn code.
- `/mtf debug_conjure` on a level ~25 Mage: Conjure Water and Conjure Food
  ranks 1-3 use Classic's spell IDs (5504-5506, 587/597/990) with "(Rank N)"
  names; Purified Water (2136) and Rye (1114) need level 15. Items not
  carried had no item data (no name, no level), so MTF falls back to
  Classic's required levels. A Food & Water trade placed both stacks.
- `/mtf debug_chimes`: Classic IDs and names for every chime spell; out of
  combat MTF read Blink's 15 s, Frost Nova's 25 s, and the wards' 30 s
  cooldowns; `C_Secrets.GetSpellCooldownSecrecy` returned 2 for all.
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
- The minimum-absorb gate (shield display v5) works: a frame anchored to a
  StatusBar's fill texture follows a secret value, and its clipping hides the
  crescent while the fill is empty. A Paladin's Seal of Righteousness shield
  no longer flickers the ring (confirmed on a Paladin).
- The break sound: the client plays no game sound by path (RaidWarning.ogg
  stayed silent); an AddOn's own file plays, also through `AddAuraSound`
  with trigger Removed when Blessing of Protection runs out.

### Open client questions

1. Forever's mana gem IDs (Conjure Mana Agate at level 28) and higher conjure
   ranks.
2. Whether `SetAlpha` with the secret absorb hides the crescent at 0 in
   combat.
3. Whether a chime played through Dyre's Sounds plays from a timer in combat, which cooldowns are
   readable out of combat, and whether the Mainline SOUNDKIT sounds exist.
4. Whether the break sound plays when a shield breaks from damage in combat.

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
- [ ] Bar size and Display size at 60% shrink each frame; the bar's applies
      after combat.
- [ ] Middle-click eats or drinks your own best with someone targeted.
- [ ] Below level 28 the gem button is greyed out and says level 28; no
      "! Mana Gem" macro.
- [ ] "! Water" and "! Food" appear in your character macros; left-click uses,
      right-click conjures, also as a keybind.
- [ ] Ice Barrier, Mana Shield, Fire Ward, Frost Ward: the ring shows in the
      shield's color and empties as you take damage, also in combat, and the
      whole ring drops the moment the shield is used up. A Priest's Power Word:
      Shield on you shows too.
- [ ] Portal bar: one button per known teleport and portal, teleports first,
      each with its rune count; a teleport or portal casts with zero runes
      (legacy talents); a portal in a party or raid sends the group message
      once, nothing when alone; a teleport emotes at the first key press or
      click after the loading screen; a spell learned in combat joins after combat;
      `/mtf debug_portals` lists the IDs (check Forever's IDs match Classic's).
- [ ] After `/reload` out of combat, the "! Polymorph" macro (Macros,
      character tab) has the line `/tm [@focus,harm,nodead,exists] !5` after
      the `/focus` line.
- [ ] Every MTF macro (Water, Food, Food & Water, Mana Gem, Polymorph) reads
      `/use`, not `/cast`; right-click of each conjure macro still conjures
      the shown rank, and "! Polymorph" and the bar click still sheep (`/use`
      casts a spell by name).
- [ ] With BugGrabber (or the taint log) on: sheep in and out of combat with
      the macro, the bar click, and the plain spell button. No "blocked from
      an action" popup, no ADDON_ACTION_FORBIDDEN, and no taint line names
      MageToolsForever.
- [ ] The moon: "! Polymorph" puts it on as you press it, in and out of
      combat, and pressing it again keeps it; a bar click marks the mob it
      sheeps; the plain Polymorph spell button gives no moon, and the bar
      still shows the sheep. `/mtf debug_polymorph` says
      `moon=from the macro and the click`.
- [ ] "Mark the sheep with the moon" off: after combat (or at once out of
      combat) "! Polymorph" and the bar's click have no `/tm` line, and no
      moon goes on; on again puts the line back.
- [ ] Locked, with no sheep up: left- and right-click the empty spot where
      the Polymorph bar sits; the clicks reach the world (target a mob or
      turn the camera behind it). With a sheep up, the bar's click sheeps
      it again; after it ends out of combat, clicks pass through again.
- [ ] Polymorph: in a party, the group message as the cast starts; the moon
      from the macro or the bar click (also solo; in a raid as assistant); the bar
      shows the name and drains, follows the mob when you tab away, empties
      when it breaks, and goes when the mob dies. Click the bar after the
      Polymorph breaks (out of combat sheep): it re-sheeps that mob and
      returns to your target; with the mob gone, nothing is cast and your
      target stays. `/mtf debug_polymorph` lists the IDs (check Forever's).
- [ ] Buff reminders: Arcane Intellect and armor icons pulse while missing
      and go once buffed; a party priest without the buff counts, a rogue
      does not; they hide as combat starts and return after; a click casts
      the buff on you, then the next member in range who lacks it, Arcane
      Brilliance for two or more (with powder), and your last armor; no
      taint or blocked-action messages; unlocked, each
      drags and resizes with the mouse wheel, and `/mtf reset` restores them;
      a drop near another icon snaps 20 apart and aligned, also with
      different sizes; Shift-drag moves the snapped group, a plain drag one icon.
- [ ] "! Polymorph" on a bar: hovering a mob and pressing it focuses and
      sheeps it, with the moon; the bar keeps its timer while you fight
      another mob; a bar click sheeps the focus again.
- [ ] Polymorph out of combat, click the bar to recast (it lands in combat),
      then click again in combat: each click recasts. A size change in combat
      applies after it.
- [ ] A Blessing of Protection from a Paladin, also in combat, draws the gold
      innermost arc and its icon; `/mtf debug_shield` confirms the IDs.
- [ ] The conjure, portal, and Polymorph bars snap to each other and to the
      buff reminders too; a Shift-dragged group keeps its spacing when it snaps.
- [ ] With WTF also installed: on a Mage the shield display shows (MTF's), on
      a Warlock it shows too (WTF's), each with only its class's shields and
      Power Word: Shield in the icon row.
- [ ] Announce page: switches and texts save, Enter keeps, Escape undoes,
      Defaults restores, the page scrolls, and each whisper uses its text.
- [ ] Unlocked: the grid covers the screen under every frame, red lines
      cross at the center, clicks pass through it, it rebuilds after a UI
      scale change, and its switch hides it.
- [ ] With Dyre's Toolkit enabled: MTF is listed under Dyre's Toolkit in the
      AddOn list; no "Install Dyre's Toolkit" line at login; MTF's page is
      under Options > AddOns > Dyre's AddOns, with Conjure, Shield, Portals,
      Polymorph, Buff Reminders, Cooldown Chimes, and Announce under it;
      `/mtf` opens it (and says out of combat in combat). `/mtf unlock` and
      `/dyre unlock` outline MTF's frames and the other Dyre's AddOns' with
      one "Dyre:" line and no "MTF:" line; the toolkit's grid shows and MTF
      draws none; MTF's pages have no unlock or grid switch, and the
      toolkit's "Unlock frames" switch unlocks MTF's frames too. A dropped MTF bar snaps
      beside another Dyre's AddOn's frame; with "Snap to the grid" on, a bar
      dropped alone centers on a grid point; Shift-drag moves a snapped group;
      positions and reminder sizes survive `/reload`. `/mtf lock` and the
      toolkit's minimap button lock every AddOn. The shield display (its
      full sample) drags, snaps beside an MTF bar, joins a Shift-drag group,
      and keeps its place after `/reload`.
- [ ] With Dyre's Toolkit disabled: MTF says once at login to install it
      from CurseForge; its page is top level again, with its "Unlock frames
      to move them" and grid switches, and its own grid and lock work as
      before (the shield display drags freely and saves its place),
      and positions saved with the toolkit stay.
- [ ] Without Dyre's Toolkit: "Unlock frames to move them" and `/mtf unlock` outline the conjure bar,
      the portal bar, and the shield display (with a full sample); all drag; unticking or
      `/mtf lock` locks both, and the switch and commands stay in step;
      `/mtf reset` puts them back.
- [ ] Mana Shield alone: the inner crescent shows, drains with its time left,
      and disappears when it breaks or ends; the outer crescent stays hidden.
- [ ] A ward, then Mana Shield: the outer crescent keeps the ward's color and
      the inner one is purple; the same in the other order.
- [ ] With Mana Shield and a ward up, the crescent refills to the total and
      both icons show; each icon drops when its shield breaks, also in combat,
      and the row closes the gap. (Check that Forever's shield buffs match by
      spell ID; WTF found curses did not.)
- [ ] With a second AddOn shipping the shield display, one ring shows and the
      other AddOn says which one draws it.
- [ ] With Dyre's Sounds installed (and the old `Sounds/` folder gone from
      MageToolsForever), no message about sounds at login; the chime and
      shield Sound dropdowns open Dyre's Sounds' menu of submenus (Dyre's
      Picks first, then Interface, the Cooldown Manager's groups, then Text to
      Speech), show the full name of the choice, play a sound when chosen, and
      other AddOns' dropdowns on the settings pages still work.
- [ ] Choices made before 0.3.0 survive the update: each chime keeps its sound
      (an old Dyre's Picks choice shows as the same Dyre's Picks sound), and
      the shield break sound keeps its choice and plays when a shield ends.
- [ ] With Dyre's Sounds disabled: MTF loads, says once at login "Install
      Dyre's Sounds to hear the chimes", the chimes page shows the switches
      without sound menus, no chime plays, and turning on the shield sound
      says once that Dyre's Sounds is needed. Enabling Dyre's Sounds again
      brings back every choice unchanged.
- [ ] With Dyre's Buff Reminders 0.2.0 or later enabled: MTF plays no chime
      (you hear each chime once, from DBR), no MTF install message for chimes,
      the settings list shows "Cooldown Chimes (Dyre's Buff Reminders)", its
      heading and tooltips and the main page's Cooldown chimes tooltip name
      DBR and `/dbr`, every chime setting is greyed out, and
      `/mtf debug_chimes` shows `playedBy=DyresBuffReminders`. DBR does not
      warn that MTF also plays chimes. MTF's chime settings are unchanged
      after a `/reload`. With Dyre's Cooldown Chimes enabled instead, the
      same holds with DCC and `/dcc`.
- [ ] Blink and Frost Nova chime half a second before they are ready, in and
      out of combat, with Talent ready by default; each spell's own
      sound, switch, and the lead change it; Text to Speech
      says "Blink ready"; Cold Snap cancels Frost Nova's chime.
- [ ] Settings survive `/reload` and stay separate on a second Mage.
