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

One-click food and water for your group, a portal bar, and with my companion AddOns, shields, buff reminders, procs, chimes, and a Polymorph bar. For WoW: Forever.

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
I play a Mage, and in every group I spent half my time on chores instead of casting. I'd conjure water, open a trade with each person, count out a stack, and then remember my armor had dropped. Finding the right portal in a spellbook full of teleports didn't help either. Mage Tools Forever is my answer, and you control all of it from one place: Mage Tools Forever's settings (`/mtf`).

Some of it comes from my other AddOns that work for every class: Dyre's Shields Up, Dyre's Buff Reminders, and Dyre's Debuff Tracker. The CurseForge app installs all three with Mage Tools Forever, and their Mage settings show right on MTF's pages. Each part has its own on/off switch on MTF's main page, so you can turn on only what you want.

### Conjure bar
- One small bar with **Water**, **Food**, **Food & Water**, and **Mana Gem** buttons, each showing how many you carry.
- **Feed your group in one click.** Target a friend and right-click to conjure the best food or water they can use. Left-click trades them a share and whispers them. A share is 10 by default, and you can pick 1 to 20, so the rest stays in your bags for the next person.
- When someone opens a trade with you, the buttons serve that person, and left-click puts their share straight into the trade window.
- **Food & Water** gives a share of both in one click, with one whisper.
- With no one targeted, left-click eats or drinks your best and right-click conjures your best. Middle-click and Shift + left-click always eat or drink, whoever you have targeted.
- **Trade only with Shift-click** is for dungeons, where your target is usually the tank or the healer. Left-click then always drinks, and Shift + left-click trades.
- The **Mana Gem** button uses your best gem on a left-click, and a right-click conjures the best gem you don't carry. Before you learn Conjure Mana Agate, the button is there and greyed out.
- MTF keeps **! Water**, **! Food**, **! Food & Water**, and **! Mana Gem** macros for your action bars. Left-click uses, right-click conjures, and they work in combat too.

### Portal bar
- The **portal bar** has a button for each teleport and portal you know, teleports first, with the runes you carry for each. The count is just information, and MTF never stops a cast because of it.
- When you open a portal, MTF tells your group where it goes.
- When you teleport yourself, MTF sends an emote like *"Dyre teleports to Ironforge."*

### Side by side or top to bottom
- **Layout** is new in 1.8.0. On the Conjure and Portals pages, set each bar to Horizontal or Vertical. Thanks to user_kegtgryr84rvp31h on CurseForge for the idea.
- **Bar size** makes each bar smaller or bigger, from 50% to 150%.

### Announce
- Every message MTF sends has its own switch and text you can edit: the trade whispers, the portal message to your group, and the teleport emote.

### Shield display, with Dyre's Shields Up installed
- Your shields show as rings around your character, and each ring drains as the shield absorbs damage.
- **Fire Ward** and **Frost Ward** show the damage they can still absorb. **Mana Shield** is a thinner ring that drains with its time left, and Frost Mages see **Ice Barrier** too.

### Buff reminders and chimes, with Dyre's Buff Reminders installed
- An icon shows when **Arcane Intellect** or your **armor** is missing, and a click casts it again. Frost Armor, Ice Armor, and Mage Armor all count.
- Arcane Intellect also checks the group members who use mana.
- There's a reminder for **Dampen Magic** or **Amplify Magic** too. It's off until you turn it on.
- After you learn Arcane Brilliance, you get a count of your **Arcane Powder**.
- **Cooldown chimes** play a sound just before Blink, Frost Nova, Counterspell, and your other key spells are ready.

### Procs, with Dyre's Buff Reminders and Dyre's Debuff Tracker installed
- **Missile Barrage** and **Fingers of Frost** each show an arc on each side of your character and play a sound. **Clearcasting** can play a sound too.
- An arc of ice crystals shows over an enemy's nameplate while it's **frozen**, so you know your Shatter talent works on it.
- A thin frost arc shows while your **chill** is on the enemy.
- The **Winter's Chill** arc over your target's nameplate fills with each stack, and it can play a note as each stack goes on.

### Crowd control, with Dyre's Debuff Tracker installed
- The **Polymorph bar** shows the time left on your sheep, and it empties if the sheep breaks early.
- Dyre's Debuff Tracker keeps a **! Polymorph** macro up to date for you, and it can tell your group when you sheep a target.
- It also tracks the burn damage from your Fireball, Pyroblast, and Frostfire Bolt on every mob.

### Moving frames
- Type `/mtf unlock`, or click Dyre's Toolkit's minimap button, and drag any frame over a grid.
- Frames snap to each other, and Shift-drag moves a group of snapped frames. Drag the conjure and portal bars from any of their buttons.
- `/mtf lock` locks the frames again, and `/mtf reset` puts them back where they started.

### Profiles
- Your settings are part of your Dyre's Toolkit profile. Copy them from another character, or export and import them as one line of text.

### Commands
- `/mtf` opens the settings, in Options > AddOns > Dyre's AddOns > Mage Tools Forever.
- `/mtf conjure` shows the food, water, and gems you carry.
- `/mtf unlock`, `/mtf lock`, and `/mtf reset` move your frames.
- `/magetools` does the same as `/mtf`, in case another AddOn uses `/mtf`.

### What gets installed with it
- Dyre's Toolkit is the home of all my AddOns, and the CurseForge app installs it for you. Keep it up to date, because the Layout setting needs 2.18.0 or later.
- Dyre's Shields Up, Dyre's Buff Reminders, and Dyre's Debuff Tracker come with it for the parts marked above. If one is missing, MTF still works and tells you once in chat what to install.

### Compatibility
For World of Warcraft: Forever 1.60.1, tested on build 70888. If a game update removes something MTF needs, MTF turns that part off and tells you once in chat.

WowUp users need WowUp 2.24.0 or later. Install MTF from the repository URL, and Dyre's Toolkit, Dyre's Shields Up, Dyre's Buff Reminders, and Dyre's Debuff Tracker the same way.

Let me know what you think!

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

Source, issues, and license (MIT): https://github.com/jbedworth/MageToolsForever
```
