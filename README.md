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
Tools Forever, and they take over your MTF settings once. MTF's Shield display,
Reminders, Chimes, Procs, and Crowd Control settings pages show their settings
(with Dyre's Toolkit 2.17.0 or later), or a button that opens them. Without
one of them, MTF works and says once in chat what to install (or enable).
Proc arcs, such as Missile Barrage and Fingers of Frost, are in Dyre's Buff
Reminders, Winter's Chill is in Dyre's Debuff Tracker (on MTF's Procs page),
and the Polymorph bar is in Dyre's Debuff Tracker (see
[Polymorph bar](#polymorph-bar)).

**Needs Dyre's Toolkit 2.5.** Dyre's Toolkit is the home of all of Dyre's
AddOns: one layout mode for every Dyre's AddOn's frames, a grid, and one
settings page. The CurseForge app installs it with Mage Tools Forever. MTF's
settings are under **Options → AddOns → Dyre's AddOns → Mage Tools Forever**.
Without Dyre's Toolkit 2.5 or later, MTF stays off and says once in chat what
to install.

## Conjure

A small bar with **Water**, **Food**, **Food & Water**, and **Mana Gem**
buttons. **Bar size** on the Conjure settings page shrinks or grows it
(50-150%), and **Layout** puts the buttons side by side (**Horizontal**) or
top to bottom (**Vertical**; Dyre's Toolkit 2.18.0 or later); see
[Moving frames](#moving-frames) to put it where you want.

**Water and food**

| Click | Friendly player targeted | No one targeted |
|---|---|---|
| Right | Conjures the best rank *they* can use | Conjures your best rank |
| Left | Trades them your **share stack size** of the best they can use, or all you have of it if less | Eats or drinks your best |
| Middle | Eats or drinks your own best | Same |
| Shift + left | Eats or drinks your own best | Same |

- **Trade only with Shift-click** (Conjure settings, off by default) swaps
  left-click and Shift + left-click: left-click always eats or drinks, even
  with a player targeted, and Shift + left-click trades. Good for dungeons,
  where your target is often the healer or the tank when you want to drink.

- **Share stack size** (Conjure settings, 1 to 20, default 10): how much one
  trade gives. It never gives more, so the rest stays for the next
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
- **Shift + left-click** eats and drinks your own best too, or trades with
  **Trade only with Shift-click** on.

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
it ("Dyre teleports to
Ironforge.") at your next key press or click, since the game allows emotes
only then. **Bar size** and **Layout** (**Horizontal** or **Vertical**;
Dyre's Toolkit 2.18.0 or later) are on the Portals settings page.

## Polymorph bar

**The Polymorph bar is in Dyre's Debuff Tracker** since MTF 1.6.0, so its
settings and the bar live in one AddOn. Dyre's Debuff Tracker draws the bar,
keeps the **"! Polymorph"** macro, and tells your group as you sheep. It takes
over your MTF Polymorph settings once (MTF keeps them as they were), and says
so once in chat. The CurseForge app installs Dyre's Debuff Tracker with
Mage Tools Forever. MTF's Crowd Control settings page shows its Polymorph
settings, or a button that opens them; without Dyre's Debuff Tracker, MTF
says once in chat what to install.

## Announce

The Announce settings page holds every message MTF sends, each with its own
switch and an editable text: the whispers for Water, Food, and Food & Water
trades, the group message for a portal, and the teleport
emote. The Polymorph group message is Dyre's Debuff Tracker's now. `%C` is the
count, `%I` the item, `%T` the player's full name, `%D` the portal's or
teleport's city, and, in the emote, `%T` is you and `%Z` your zone when it is sent. Press Enter to keep
an edit or Escape to undo it; **Defaults** restores the page.

## Moving frames

Dyre's Toolkit moves every MTF frame (the conjure and portal bars), together with the frames of your other Dyre's AddOns. Type `/mtf unlock` or `/dyre unlock`, tick
**Unlock frames** on the Dyre's AddOns settings page, or click the minimap
button: every frame gets a gold outline, and you can drag it; drag the
conjure and portal bars from any of their buttons. Frames are magnetic: drop one near another and it
snaps beside it. Hold **Shift** while dragging to move a whole snapped group
together. `/mtf lock` (or `/dyre lock`) locks them again, and `/mtf reset`
puts MTF's frames back in their default places and sizes. Everything starts
locked. The grid and "Snap to the grid" are on the Dyre's AddOns page
(`/dyre`). Every frame grows and shrinks around its middle, and the size
sliders on each page have a gold mark at their default.

## Profile

With Dyre's Toolkit 2.10.0 or newer, MTF's settings are part of your Dyre's
Toolkit profile, one per character: every switch and slider, the frames'
places and sizes, and your messages. On the Dyre's AddOns settings page
(`/dyre`), **Copy settings from** takes another character's settings (or
the Defaults) for every Dyre's AddOn at once, and **Export profile** and
**Import profile** move them as one line of text. A copy applies at once,
with no reload, and only out of combat. Each character keeps its own MTF
macros.

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
| `/mtf debug_click` | Diagnostics: what each conjure button does for each mouse button |

`/magetools` works the same, in case another AddOn uses `/mtf`.

## Compatibility

Tested on the Forever beta client 1.60.1, build 70888. MTF keeps working on later beta
builds; if a client update removes an API it needs, it turns that feature off
with one chat message. Spell and item IDs are Classic's; `/mtf debug_conjure`
shows what your client knows.

WowUp users (2.24.0 or later): install from the repository URL, and Dyre's
Toolkit, Dyre's Shields Up, Dyre's Buff Reminders, and Dyre's Debuff Tracker the same way; GitHub releases carry
the Forever metadata WowUp needs.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT. See [LICENSE](LICENSE).
