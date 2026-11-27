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
| Relations | Dyre's Toolkit (`dyres-toolkit`), Dyre's Shields Up (`dyres-shields-up`), Dyre's Buff Reminders (`dyres-buff-reminders`), and Dyre's Debuff Tracker (`dyres-debuff-tracker`, project 1777574): required dependencies, set by each CI upload; add them by hand on any file uploaded through the website. |
| Author shown | Dyre, set through the CurseForge account's username |
| License | MIT License |
| Logo | artwork/mage-tools-forever-logo.png (1024 x 1024) |
| Source | https://github.com/jbedworth/MageToolsForever |
| Issues | https://github.com/jbedworth/MageToolsForever/issues |
| Donation | Ko-fi, https://ko-fi.com/dyre_janelle (the project's Donation field) |

## Summary

Mage tools for World of Warcraft: Forever: conjure and trade food and water by level, and a portal bar. Installs Dyre's Shields Up, Dyre's Buff Reminders, and Dyre's Debuff Tracker for shields, buff tracking, cooldown chimes, and the Polymorph bar.

## Screenshots

Upload these from `artwork/screenshots/`, with these captions:

| File | Caption |
| --- | --- |
| conjure-bar.png | The conjure bar: Water, Food, Food & Water, and Mana Gem. |
| portal-bar.png | The portal bar: every teleport and portal you know, with your runes. |
| settings-conjure.png | Conjure settings: macros, share stack size, and bar size. |
| settings-announce.png | Every whisper, group message, and emote, each with its own switch and text. |

Not in the gallery since 1.2.0 (they show features that moved, or the old
lock and grid switches): shield-display.png, settings-shield.png,
settings-chimes-sounds.png, settings-main.png, and unlocked-grid.png; since
1.6.0, polymorph-bar.png (Dyre's Debuff Tracker's bar now). Retake
settings-main.png (the main page now has two switches) and unlocked-grid.png
(Dyre's Toolkit's grid with the conjure and portal bars) before adding them
again.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Mage Tools Forever** is a growing set of quality-of-life tools for Mages: Conjure, Portals, and Announce. Each tool has its own switch and settings page.

Your shield display, buff reminders, cooldown chimes, and Polymorph bar now come from three of Dyre's AddOns that work for every class: **Dyre's Shields Up** draws the shield display, **Dyre's Buff Reminders** shows Arcane Intellect, your armor, and Dampen or Amplify Magic, and plays your cooldown chimes, and **Dyre's Debuff Tracker** draws the Polymorph bar and keeps the "! Polymorph" macro. The CurseForge app installs all three with Mage Tools Forever.

### Conjure
- A movable bar with Water, Food, Food & Water, and Mana Gem buttons.
- Target a friend: right-click conjures the best food or water *they* can use; left-click trades them a share of it (10 by default, you pick stacks of 1 to 20), or all you have if less, and whispers them. The rest stays for the next party member.
- Someone opens a trade with you? The buttons serve them: left-click puts their share straight into the window.
- Food & Water gives a share of both in one click, with one whisper; right-click conjures them in turn.
- No one targeted: left-click eats or drinks your best; right-click conjures your best. Middle-click and Shift + left-click always eat or drink your own best, whoever you have targeted.
- Mostly drinking in dungeons? Turn on **Trade only with Shift-click**: left-click always eats or drinks, and Shift + left-click trades.
- Mana gems: left-click uses your best gem; right-click conjures the best one you don't carry.
- For your action bars: MTF keeps **! Water**, **! Food**, **! Food & Water**, and **! Mana Gem** macros in your character macros. Left-click uses, right-click conjures, also works in combat.

### Portals
- A bar with a button for each teleport and portal you know, teleports first, with the runes you carry for each. The count is only information: MTF never stops a cast for lack of runes (legacy talents can make this work without runes).
- Opening a portal tells your group where it goes. Teleporting yourself emotes it: *"Dyre summons powerful arcane energies to whisk themselves away to Ironforge."* (both on by default; see Announce).

### Announce
- Every message MTF sends has its own switch and text you can edit: the water, food, and Food & Water trade whispers, the portal group message, and the teleport emote. The defaults credit Mage Tools Forever (MTF).

### Shields, buff reminders, and cooldown chimes
- **Dyre's Shields Up** draws the shield display; **Dyre's Buff Reminders** shows the buff reminders and plays the cooldown chimes. Both work for every class, and the CurseForge app installs them with Mage Tools Forever.
- Coming from MTF 1.1 or older? They take over your MTF settings for these once.
- MTF's Shield display, Reminders, Chimes, Procs, and Crowd Control settings pages show their settings, or a button that opens them.
- Without one of them, MTF still works and says once in chat what to install or enable.

### Needs Dyre's Toolkit
**Dyre's Toolkit** (2.3 or later) is the home of all of Dyre's AddOns; the CurseForge app installs it for you. MTF's settings sit under Options > AddOns > Dyre's AddOns, and the frames of every Dyre's AddOn unlock, lock, snap, and resize together.

### Moving frames
- `/mtf unlock` (or Dyre's Toolkit's Unlock frames switch or its minimap button) outlines every MTF frame so you can drag it, over Dyre's Toolkit's grid. Frames snap to each other, Shift-drag moves a snapped group, and every frame grows and shrinks around its middle. Drag the conjure and portal bars from any of their buttons.
- `/mtf lock` locks them again; `/mtf reset` puts MTF's frames back in their default places.

### Commands
- `/mtf` or `/mtf options` opens the settings (Options > AddOns > Dyre's AddOns > Mage Tools Forever).
- `/mtf conjure` shows the food, water, and gems you carry.
- `/mtf unlock`, `/mtf lock`, and `/mtf reset` move your frames.
- `/magetools` works the same, in case another AddOn uses `/mtf`.

### Compatibility
For World of Warcraft: Forever 1.60.1 (tested on build 70450). If a client update removes an API MTF needs, MTF turns off what it cannot run and says so once in chat.

WowUp users (2.24.0 or later): install from the repository URL, and Dyre's Toolkit, Dyre's Shields Up, and Dyre's Buff Reminders the same way; GitHub releases carry the Forever metadata WowUp needs.

Source, issues, and license (MIT): https://github.com/jbedworth/MageToolsForever
```
