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

Mage tools for World of Warcraft: Forever: conjure and trade food and water by level, a portal bar, and a Polymorph bar. Installs Dyre's Shields Up and Dyre's Buff Reminders for shields, buff tracking, and cooldown chimes.

## Screenshots

Upload these from `artwork/screenshots/`, with these captions:

| File | Caption |
| --- | --- |
| conjure-bar.png | The conjure bar: Water, Food, Food & Water, and Mana Gem. |
| portal-bar.png | The portal bar: every teleport and portal you know, with your runes. |
| polymorph-bar.png | The Polymorph bar: the sheeped mob and the time left. Click it to sheep again. |
| settings-conjure.png | Conjure settings: macros, share stack size, and bar size. |
| settings-announce.png | Every whisper, group message, and emote, each with its own switch and text. |

Not in the gallery since 1.2.0 (they show features that moved, or the old
lock and grid switches): shield-display.png, settings-shield.png,
settings-chimes-sounds.png, settings-main.png, and unlocked-grid.png. Retake
settings-main.png (the main page now has three switches) and unlocked-grid.png
(Dyre's Toolkit's grid with the conjure, portal, and Polymorph bars) before
adding them again.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Mage Tools Forever** is a growing set of quality-of-life tools for Mages: Conjure, Portals, the Polymorph bar, and Announce. Each tool has its own switch and settings page.

Your shield display, buff reminders, and cooldown chimes now come from two of Dyre's AddOns that work for every class: **Dyre's Shields Up** draws the shield display, and **Dyre's Buff Reminders** shows Arcane Intellect, your armor, and Dampen or Amplify Magic, and plays your cooldown chimes. The CurseForge app installs both with Mage Tools Forever.

### Conjure
- A movable bar with Water, Food, Food & Water, and Mana Gem buttons.
- Target a friend: right-click conjures the best food or water *they* can use; left-click trades them a share of it (10 by default, you pick stacks of 1 to 20), or all you have if less, and whispers them. The rest stays for the next party member.
- Someone opens a trade with you? The buttons serve them: left-click puts their share straight into the window.
- Food & Water gives a share of both in one click, with one whisper; right-click conjures them in turn.
- No one targeted: left-click eats or drinks your best; right-click conjures your best. Middle-click always eats or drinks your own best, whoever you have targeted.
- Mana gems: left-click uses your best gem; right-click conjures the best one you don't carry.
- For your action bars: MTF keeps **! Water**, **! Food**, **! Food & Water**, and **! Mana Gem** macros in your character macros. Left-click uses, right-click conjures, also works in combat.

### Portals
- A bar with a button for each teleport and portal you know, teleports first, with the runes you carry for each. The count is only information: MTF never stops a cast for lack of runes (legacy talents can make this work without runes).
- Opening a portal tells your group where it goes. Teleporting yourself emotes it: *"Dyre summons powerful arcane energies to whisk themselves away to Ironforge."* (both on by default; see Announce).

### Polymorph bar
- Sheep with the **"! Polymorph"** macro: it focuses the mob under your mouse, marks it with the moon, and sheeps it, also in combat.
- The bar shows your focus's name and the Polymorph's time left while you fight something else. If it breaks early, the bar empties so you see it.
- Click the bar to sheep your focus again.
- As you start casting in a group: *"Sheeping Defias Pillager; you spank it, you tank it."*
- Bar size, Bar width, Bar height, Text size, and Opacity on the Polymorph settings page fit it to your screen; Reset size puts the width, height, and text size back.

### Announce
- Every message MTF sends has its own switch and text you can edit: the water, food, and Food & Water trade whispers, the portal and Polymorph group messages, and the teleport emote. The defaults credit Mage Tools Forever (MTF).

### Shields, buff reminders, and cooldown chimes
- **Dyre's Shields Up** draws the shield display; **Dyre's Buff Reminders** shows the buff reminders and plays the cooldown chimes. Both work for every class, and the CurseForge app installs them with Mage Tools Forever.
- Coming from MTF 1.1 or older? They take over your MTF settings for these once.
- MTF's Shield, Buff Reminders, and Cooldown Chimes settings pages each have a button that opens their settings.
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
