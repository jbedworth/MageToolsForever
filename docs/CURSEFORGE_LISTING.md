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
| Author shown | Dyre, set through the CurseForge account's username |
| License | MIT License |
| Source | https://github.com/jbedworth/MageToolsForever |
| Issues | https://github.com/jbedworth/MageToolsForever/issues |

## Summary

Quality-of-life tools for Mages in World of Warcraft: Forever: conjured food, water, and mana gems with level-matched trading, a shield absorb ring, and cooldown chimes.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Mage Tools Forever** is a growing set of quality-of-life tools for Mages. Each tool has its own switch and settings page.

### Conjure
- A movable bar with Water, Food, and Mana Gem buttons.
- Target a friend: right-click conjures the best food or water *they* can use; left-click trades them a share of it (10 by default, you pick 1 to 20), or all you have if less, and whispers them. The rest stays for the next party member.
- Someone opens a trade with you? The buttons serve them: left-click puts their share straight into the window.
- No one targeted: left-click eats or drinks your best; right-click conjures your best.
- Middle-click always eats or drinks your own best, whoever you have targeted.
- A Food & Water button gives a share of both in one click, with one whisper; right-click conjures them in turn.
- Mana gems: left-click uses your best gem; right-click conjures the best one you don't carry.
- For your action bars: MTF keeps **! Water**, **! Food**, and **! Mana Gem** macros in your character macros. Left-click uses, right-click conjures.

### Portals
- A bar with a button for each teleport and portal you know, and the runes you carry. It never stops a cast for lack of runes.
- Tells your group where a portal you open goes, and emotes your teleports.

### Polymorph bar
- The sheeped mob's name and the time left, following the mob as you change target.
- "Sheeping %T; you spank it, you tank it" to your group as you cast, and the moon marker when it lands.
- Click the bar to sheep the same mob again.

### Buff reminders
- An icon with a pulsing border for each buff you are missing: Arcane Intellect (also for your group) and your armor.
- Click an icon to cast the buff: on you, then each group member who lacks it (Arcane Brilliance for two or more).
- Drag and resize each icon on its own.

### Announce
- Every whisper and group message has its own switch and text you can edit.

### Shield display
- A segmented crescent beside your character that fills with your remaining shield: full when it lands and draining as it absorbs, with the amount below, also in combat.
- Ice Barrier blue, Mana Shield purple, the wards in fire and frost, and any shield another player puts on you, like Power Word: Shield.
- Drops away the moment the shield is used up. Mana Shield gets its own inner crescent that drains with its time left. Optional sound when a shield ends.

### Cooldown chimes
- A sound just before Blink, Frost Nova, Counterspell, Ice Block, Ice Barrier, Evocation, and other spells you pick are ready again, also in combat.
- Pick the sound and how early it plays.

### Commands
- `/mtf` or `/mtf options` opens the settings (Options > AddOns).
- `/mtf conjure` shows the food, water, and gems you carry.
- `/magetools` works the same, in case another AddOn uses `/mtf`.

### Compatibility
Beta: tested on the Forever beta client 1.60.1. MTF keeps working on later beta builds; if a client update removes an API it needs, it turns that feature off with one chat message.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases carry the Forever metadata WowUp needs.

Source, issues, and license (MIT): https://github.com/jbedworth/MageToolsForever
```
