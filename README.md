# Mage Tools Forever

Quality-of-life tools for Mages in World of Warcraft: Forever (beta). Each tool
has its own switch on the main settings page and its own settings page in
**Options → AddOns → Mage Tools Forever**, or type `/mtf`. Settings are saved
per character.

**Sounds need Dyre's Sounds.** The cooldown chimes and the sound when a
shield ends come from Dyre's Sounds, a small library AddOn that all of Dyre's
AddOns share, so your computer keeps one copy of the sound files. The
CurseForge app installs it with Mage Tools Forever; otherwise get it from
CurseForge or [GitHub](https://github.com/jbedworth/DyresSounds). Without it,
MTF works but plays no sounds, and says so once in chat.

**Needs Dyre's Toolkit 2.0.** Dyre's Toolkit is the home of all of Dyre's
AddOns: one layout mode for every Dyre's AddOn's frames, a grid, and one
settings page. The CurseForge app installs it with Mage Tools Forever. MTF's
settings are under **Options → AddOns → Dyre's AddOns → Mage Tools Forever**.
Without Dyre's Toolkit 2.0 or later, MTF stays off and says once in chat what
to install.

## Conjure

A small bar with **Water**, **Food**, **Food & Water**, and **Mana Gem**
buttons. **Bar size** on the Conjure settings page shrinks or grows it
(50-150%); see [Moving frames](#moving-frames) to put it where you want.

**Water and food**

| Click | Friendly player targeted | No one targeted |
|---|---|---|
| Right | Conjures the best rank *they* can use | Conjures your best rank |
| Left | Trades them your **share stack size** of the best they can use, or all you have of it if less | Eats or drinks your best |
| Middle | Eats or drinks your own best | Same |

- **Share stack size** (Conjure settings, 1 to 20, default 10): how much one
  left-click trade gives. It never gives more, so the rest stays for the next
  party member. As you click, MTF makes one stack of exactly that much, using
  no extra bag space where it can: it tops up a smaller stack you already
  have, or merges small ones. Only when all you carry is bigger stacks does
  it need one free bag slot to split into, and then it tells you. It puts
  the stack into the trade window and whispers the player (at most once
  every 30 seconds per player; see [Announce](#announce)). Click Food after Water to add both to the same trade. You press
  **Trade** yourself.
- **Someone opens a trade with you?** While the trade window is open the
  buttons serve your trade partner, whoever you have targeted: left-click
  puts their share straight into the window, and right-click conjures what
  they can use.
- With none they can use, MTF tells you to conjure some first.
- One cast doesn't make a full stack: right-click again until you have enough.
  The button shows how many of the item it would use or give you carry.

**Food & Water**, the third button, does both at once:

- **Left-click** with a friend targeted (or a trade open) trades them a share
  of water **and** food in one click, with one whisper. With no one targeted,
  it eats and drinks your best.
- **Right-click** conjures water, then food, in turn: the game allows one
  spell per click.
- **Middle-click** always eats and drinks your own best.

**Mana gems**

- Left- or middle-click uses your best mana gem; right-click conjures the best
  rank you don't carry (you can carry one of each).
- Before you learn Conjure Mana Agate (level 28), the button is greyed out and
  tells you when it comes.

**Macros for your action bars:** MTF keeps **! Water**, **! Food**,
**! Food & Water**, and **! Mana Gem** in your character macros (each once you know its spell). Drag
them from the Macros window to a bar: left-click eats, drinks, or uses;
right-click conjures, also in combat. Turn **Keep conjure macros** off to
remove them. (On Forever, `/click` macros do not press AddOn buttons, so these
use the game's own `/use` and `/castsequence`.)

The game lets the buttons change only out of combat, so a target or bag change
in combat updates them when combat ends.

## Portals

A small bar with a button for each teleport and portal you know, teleports
first, showing how many Runes of Teleportation or Runes of Portals you carry.
The count is only information: MTF never stops a cast because it is zero, and
the game decides. The buttons work in combat; a spell you learn in combat
joins the bar when combat ends. When you open a portal in a group, MTF tells
your raid or party where it goes, and when you teleport yourself, you emote
it ("Dyre summons powerful arcane energies to whisk themselves away to
Ironforge.") at your next key press or click, since the game allows emotes
only then. **Bar size** is on the Portals settings
page.

## Polymorph bar

A bar with your Polymorph's time left and the sheeped mob's name, in the same
style as Warlock Tools Forever's DoT bars. It follows the mob when you change
target, and if the Polymorph breaks early, the bar empties so you see it.

- As you start casting in a group, MTF tells your party or raid: "Sheeping
  Defias Pillager; you spank it, you tank it."
- The moon marker: for the moon, use the **"! Polymorph"** macro or click
  the bar. They mark the mob as you press them, also in combat, and a second
  press never toggles the moon off. A Polymorph from the plain spell button
  gets no moon: the game does not let AddOns set markers. (In a raid, only
  the leader and assistants can mark.)
- With no sheep to click, the bar lets your clicks through to the world.
- **"! Polymorph"** in your character macros (once you know Polymorph) focuses
  the hostile mob under your mouse (or your target, out of combat) and sheeps
  your focus. The bar follows your focus, so it keeps the timer while you fight
  something else.
- **Click the bar** to sheep your focus again; with no focus, MTF targets the
  mob by name, casts the same Polymorph, and goes back to your target. The game lets the
  click change only out of combat, so after sheeping a different mob in
  combat, the click catches up when combat ends. With several mobs of the same
  name, it picks the nearest.
- The marker switch and **Bar size** are on the Polymorph settings page. The
  switch takes the `/tm` line out of "! Polymorph" and the bar's click (or
  puts it back). If you mark with your own `/tm` macro, use `!` the same way
  (`!5`), or turn MTF's marker off.
- Make the bar your own on the Polymorph settings page: **Bar width**
  (120-400, default 200), **Bar height** (10-40, default 16; the icon
  follows), **Text size** (50-200%), and **Opacity** (10-100%). A gold mark
  shows each default, and **Reset size** puts the width, height, and text
  size back. **Bar size** scales the whole bar on top. Opacity fades
  the bar at once, also in combat; a size change in combat applies when
  combat ends.

## Buff reminders

An icon with a pulsing gold border for each buff you are missing, out of
combat: **Arcane Intellect** (also for group members who use mana, with a
count; the tooltip says who), your **armor** (Frost, Ice, or Mage Armor), and,
if you turn it on, **Dampen or Amplify Magic**. Each icon disappears as soon as
the buff is up, and they all hide in combat, when the game keeps buffs from
AddOns.

**Click an icon to cast the buff.** Arcane Intellect goes to you first, then
to the first group member in range who lacks it; click again as each one
lands until the icon goes away. With two or more missing, it casts Arcane
Brilliance if you know it and carry Arcane Powder. Warriors and rogues are
never counted or buffed. Armor recasts the armor you used last (or your best),
and Dampen or Amplify Magic the same.

Unlock frames to drag each icon where you want it and scroll over it to
resize it; like every MTF frame, they snap together (see
[Moving frames](#moving-frames)).

## Announce

The Announce settings page holds every message MTF sends, each with its own
switch and an editable text: the whispers for Water, Food, and Food & Water
trades, the group messages for a portal and a Polymorph, and the teleport
emote. `%C` is the
count, `%I` the item, `%T` the player's full name, `%D` the portal's or
teleport's city, and, in the emote, `%T` is you and `%Z` your zone when it is sent. Press Enter to keep
an edit or Escape to undo it; **Defaults** restores the page.

## Shield display

A segmented crescent beside your character that fills with your remaining shield:
**Ice Barrier** (blue), **Mana Shield** (purple), **Fire Ward** (orange),
**Frost Ward** (pale blue), and shields others put on you, like a Priest's
**Power Word: Shield**: full when the shield lands and draining as it absorbs,
with the amount as a number below. It tracks live, also in
combat, and drops away the moment the shield is used up.

- With several shields up (say Ice Barrier, Mana Shield, and a ward), the
  crescent shows their combined total, refilled as each one lands, and a row
  of icons under the number shows which are up, each in its own spot; each
  icon drops the moment its shield breaks or ends, also in combat.
- A Paladin's **Blessing of Protection** on you has no absorb either: it shows
  as a gold arc innermost of all, draining with its time left.
- Mana Shield spends your mana rather than adding to your absorb, so the game
  leaves it out of the total. It gets its own thinner crescent, nested
  inside, that drains with its time left and disappears when it breaks or
  ends. Absorb shields drain only as they absorb, and drop when they break or
  expire.
- The shield display works for any shield, so other AddOns can ship it too.
  If more than one does (Warlock Tools Forever ships it too), you still see one
  ring, from the newest version among the AddOns running on your character.
- **Display size** on the Shield settings page shrinks or grows it (50-150%).
- While frames are unlocked (see [Moving frames](#moving-frames)) it shows a
  full sample of every part to drag; locked (the default), it never blocks
  clicks on the world.
- Optional: a sound when a shield ends or breaks, also in combat, chosen
  from Dyre's Sounds.

## Cooldown chimes

A sound just before a spell is ready again, also in combat: **Blink**,
**Frost Nova**, **Counterspell**, **Ice Block**, **Ice Barrier**, and
**Evocation** by default; Cold Snap, the wards, Cone of Cold, Fire Blast,
Presence of Mind, Arcane Power, and Combustion are off by default. Each spell
has its own switch and its own sound, picked from Dyre's Sounds' menu, like
the Cooldown Manager's sound picker: Dyre's Picks, the game's interface
sounds, the Cooldown Manager's 93 alert sounds, and Text to Speech, which says
the spell's name ("Blink ready"). Every spell starts on Talent ready. Pick how
early it plays (default half a second) on the Cooldown Chimes settings page.
Without Dyre's Sounds, the chimes play nothing.

**Dyre's Shields Up** shows the shield display for every class. With it
installed, MTF draws no shield ring of its own and greys out its shield
settings; use `/dsu` for them.

**Dyre's Buff Reminders** shows buff reminders for every class. With it
installed, MTF hides its own reminder icons, so you never see two for one
buff, and keeps its own reminder settings as they are. Use `/dbr` for them.

**Dyre's Buff Reminders** also plays these chimes for every class. With it
installed, MTF plays no chimes of its own (so you never hear two), and its
chime settings are greyed out; use `/dbr` instead. On its first run it copies
your MTF chime settings, and MTF keeps its own as they are.

The game hides cooldowns from AddOns in combat, so MTF times each one from your
cast, using the real cooldown it read the last time you cast the spell out of
combat. Cold Snap cancels the Frost chimes, since it makes them ready at once.

## Moving frames

Dyre's Toolkit moves every MTF frame (the conjure, portal, and Polymorph
bars, the buff reminders, and the shield display), together with the frames
of your other Dyre's AddOns. Type `/mtf unlock` or `/dyre unlock`, tick
**Unlock frames** on the Dyre's AddOns settings page, or click the minimap
button: every frame gets a gold outline, and you can drag it; drag the
conjure and portal bars from any of their buttons, and scroll over a buff
reminder to resize it. Frames are magnetic: drop one near another and it
snaps beside it. Hold **Shift** while dragging to move a whole snapped group
together. `/mtf lock` (or `/dyre lock`) locks them again, and `/mtf reset`
puts MTF's frames back in their default places and sizes. Everything starts
locked. The grid and "Snap to the grid" are on the Dyre's AddOns page
(`/dyre`). Every frame grows and shrinks around its middle, and the size
sliders on each page have a gold mark at their default.

## Commands

| Command | What it does |
|---|---|
| `/mtf` or `/mtf options` | Open the settings |
| `/mtf conjure` | Show the food, water, and gems you carry, and the share size |
| `/mtf unlock` | Unlock every MTF frame, so you can drag them |
| `/mtf lock` | Lock them again where they are |
| `/mtf reset` | Move the MTF frames back to their default places |
| `/mtf debug_conjure` | Diagnostics: each conjure rank as the client knows it, macros, recent trades |
| `/mtf debug_shield` | Diagnostics: the absorb APIs and the shields MTF tracks |
| `/mtf debug_chimes` | Diagnostics: each chime spell, its cooldown, and the sound |
| `/mtf debug_portals` | Diagnostics: each teleport and portal as the client knows it, and your runes |
| `/mtf debug_polymorph` | Diagnostics: the Polymorph IDs, the sheeped mob, the click, and the moon setting |
| `/mtf debug_reminders` | Diagnostics: each buff reminder and who lacks the buff |
| `/mtf debug_click` | Diagnostics: what each conjure button does for each mouse button |

`/magetools` works the same, in case another AddOn uses `/mtf`.

## Compatibility

Tested on the Forever beta client 1.60.1, build 70450. MTF keeps working on later beta
builds; if a client update removes an API it needs, it turns that feature off
with one chat message. Spell and item IDs are Classic's; `/mtf debug_conjure`
shows what your client knows.

WowUp users (2.24.0 or later): install from the repository URL, and Dyre's
Sounds (github.com/jbedworth/DyresSounds) and Dyre's Toolkit
the same way; GitHub releases carry
the Forever metadata WowUp needs.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT. See [LICENSE](LICENSE).
