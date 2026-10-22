# Mage Tools Forever

Quality-of-life tools for Mages in World of Warcraft: Forever (beta). Each tool
has its own switch on the main settings page and its own settings page in
**Options → AddOns → Mage Tools Forever**, or type `/mtf`. Settings are saved
per character.

**Shields, buff reminders, and cooldown chimes come from Dyre's Shields Up
and Dyre's Buff Reminders.** Since 1.2.0, MTF no longer has its own copies:
**Dyre's Shields Up** draws the shield display, and **Dyre's Buff Reminders**
shows Arcane Intellect, your armor, and Dampen or Amplify Magic, and plays the
cooldown chimes, for every class. The CurseForge app installs both with Mage
Tools Forever, and they take over your MTF settings once. MTF's Shield, Buff
Reminders, and Cooldown Chimes settings pages each have a button that opens
their settings. Without one of them, MTF works and says once in chat what to
install (or enable).

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

## Announce

The Announce settings page holds every message MTF sends, each with its own
switch and an editable text: the whispers for Water, Food, and Food & Water
trades, the group messages for a portal and a Polymorph, and the teleport
emote. `%C` is the
count, `%I` the item, `%T` the player's full name, `%D` the portal's or
teleport's city, and, in the emote, `%T` is you and `%Z` your zone when it is sent. Press Enter to keep
an edit or Escape to undo it; **Defaults** restores the page.

## Moving frames

Dyre's Toolkit moves every MTF frame (the conjure, portal, and Polymorph
bars), together with the frames of your other Dyre's AddOns. Type `/mtf unlock` or `/dyre unlock`, tick
**Unlock frames** on the Dyre's AddOns settings page, or click the minimap
button: every frame gets a gold outline, and you can drag it; drag the
conjure and portal bars from any of their buttons. Frames are magnetic: drop one near another and it
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
| `/mtf debug_portals` | Diagnostics: each teleport and portal as the client knows it, and your runes |
| `/mtf debug_polymorph` | Diagnostics: the Polymorph IDs, the sheeped mob, the click, and the moon setting |
| `/mtf debug_click` | Diagnostics: what each conjure button does for each mouse button |

`/magetools` works the same, in case another AddOn uses `/mtf`.

## Compatibility

Tested on the Forever beta client 1.60.1, build 70450. MTF keeps working on later beta
builds; if a client update removes an API it needs, it turns that feature off
with one chat message. Spell and item IDs are Classic's; `/mtf debug_conjure`
shows what your client knows.

WowUp users (2.24.0 or later): install from the repository URL, and Dyre's
Toolkit, Dyre's Shields Up, and Dyre's Buff Reminders the same way; GitHub releases carry
the Forever metadata WowUp needs.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT. See [LICENSE](LICENSE).
