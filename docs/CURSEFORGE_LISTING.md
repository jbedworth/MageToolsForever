# CurseForge listing

Copy-ready text for the CurseForge project form. Keep it aligned with README.md
and the tested client; do not advertise clients or versions that have not been
tested.

## Project fields

| Field | Value |
| --- | --- |
| Name | Mage Tools Forever |
| Class | Addons |
| Main category | Mage. Keep it identical to the TOC `## Category`, which groups the AddOn in the in-game AddOn list. |
| Additional categories | Bags & Inventory, Buffs & Debuffs (CurseForge allows up to 4; unrelated ones can send the project back for changes). |
| Relations | Dyre's Toolkit (`dyres-toolkit`), Dyre's Shields Up (`dyres-shields-up`), and Dyre's Buff Reminders (`dyres-buff-reminders`): required dependencies, set by each CI upload; add them by hand on any file uploaded through the website. |
| Author shown | Dyre, set through the CurseForge account's username |
| License | MIT License |
| Logo | artwork/mage-tools-forever-logo.png (1024 x 1024) |
| Source | https://github.com/jbedworth/MageToolsForever |
| Issues | https://github.com/jbedworth/MageToolsForever/issues |
| Donation | Ko-fi, https://ko-fi.com/dyre_janelle (the project's Donation field) |

## Summary

Quality-of-life tools for Mages in World of Warcraft: Forever: conjured food and water with level-matched trading, and portal and Polymorph bars. Comes with Dyre's Shields Up and Dyre's Buff Reminders for your shields, buffs, and cooldown chimes.

## Screenshots

Upload these from `artwork/screenshots/`, with these captions:

| File | Caption |
| --- | --- |
| conjure-bar.png | The conjure bar: Water, Food, Food & Water, and Mana Gem. |
| portal-bar.png | The portal bar: every teleport and portal you know, with your runes. |
| polymorph-bar.png | The Polymorph bar: the sheeped mob and the time left. Click it to sheep again. |
| unlocked-grid.png | `/mtf unlock`: a grid marks the screen's center while you drag every frame into place. |
| settings-main.png | One switch per tool, one lock for every frame, and the grid. |
| settings-conjure.png | Conjure settings: macros, bar size, and share stack size. |
| settings-announce.png | Every whisper, group message, and emote, each with its own switch and text. |

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Mage Tools Forever** is a growing set of quality-of-life tools for Mages. Each tool has its own switch and settings page.

### Conjure
- A movable bar with Water, Food, Food & Water, and Mana Gem buttons.
- Target a friend: right-click conjures the best food or water *they* can use; left-click trades them a share of it (10 by default, you pick 1 to 20), or all you have if less, and whispers them. The rest stays for the next party member.
- Someone opens a trade with you? The buttons serve them: left-click puts their share straight into the window.
- Food & Water gives a share of both in one click, with one whisper; right-click conjures them in turn.
- No one targeted: left-click eats or drinks your best; right-click conjures your best. Middle-click always eats or drinks your own best, whoever you have targeted.
- Mana gems: left-click uses your best gem; right-click conjures the best one you don't carry.
- For your action bars: MTF keeps **! Water**, **! Food**, **! Food & Water**, and **! Mana Gem** macros in your character macros. Left-click uses, right-click conjures, also in combat.

### Portals
- A bar with a button for each teleport and portal you know, teleports first, with the runes you carry for each. The count is only information: MTF never stops a cast for lack of runes.
- Opening a portal tells your group where it goes. Teleporting yourself emotes it: *"Dyre summons powerful arcane energies to whisk themselves away to Ironforge."*

### Polymorph bar
- The sheeped mob's name and your Polymorph's time left, following the mob as you change target. If it breaks early, the bar empties so you see it.
- As you start casting in a group: *"Sheeping Defias Pillager; you spank it, you tank it."* For the moon marker, use the "! Polymorph" macro or click the bar: they mark the mob as you press them, also in combat. A Polymorph from the plain spell button gets no moon (the game does not let AddOns set markers).
- Click the bar to sheep your focus again. A "! Polymorph" macro focuses the mob under your mouse and sheeps it.
- Set the bar's width, height, text size, and opacity to suit your screen.

### Announce
- Every message MTF sends has its own switch and text you can edit: the water, food, and Food & Water trade whispers, the portal and Polymorph group messages, and the teleport emote. The defaults credit Mage Tools Forever (MTF).

### Shields, buff reminders, and cooldown chimes
- **Dyre's Shields Up** draws the shield display, and **Dyre's Buff Reminders** shows Arcane Intellect, your armor, and Dampen or Amplify Magic and plays your cooldown chimes, for every class. The CurseForge app installs both with Mage Tools Forever, and they take over your MTF settings once.
- MTF's Shield, Buff Reminders, and Cooldown Chimes settings pages each open their settings with one click.

### Needs Dyre's Toolkit
**Dyre's Toolkit** 2.0 is the home of all of Dyre's AddOns; the CurseForge app installs it for you. MTF's settings sit under Dyre's AddOns, and the frames of every Dyre's AddOn unlock, lock, snap, and resize together.

### Moving frames
- `/mtf unlock` (or Dyre's Toolkit's switch or minimap button) outlines every MTF frame so you can drag it, with a grid that marks the center of your screen; frames snap to each other and grow and shrink around their middle. `/mtf lock` locks them again; `/mtf reset` puts them back.

### Commands
- `/mtf` or `/mtf options` opens the settings (Options > AddOns).
- `/mtf conjure` shows the food, water, and gems you carry.
- `/mtf unlock`, `/mtf lock`, and `/mtf reset` move your frames.
- `/magetools` works the same, in case another AddOn uses `/mtf`.

### Compatibility
Tested on the Forever beta client 1.60.1, build 70450. MTF keeps working on later beta builds; if a client update removes an API it needs, it turns that feature off with one chat message.

WowUp users (2.24.0 or later): install from the repository URL, and Dyre's Toolkit, Dyre's Shields Up, and Dyre's Buff Reminders the same way; GitHub releases carry the Forever metadata WowUp needs.

Source, issues, and license (MIT): https://github.com/jbedworth/MageToolsForever
```
