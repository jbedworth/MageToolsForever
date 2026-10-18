# Changelog

Player-facing changes for each Mage Tools Forever release, newest first. The
release builder copies the section for the TOC version into the GitHub release
notes and the CurseForge changelog, and fails if that section is missing.

## 0.2.2-beta

- Shield display: the outer crescent is centered with the inner ones again; since the last update it was drawn lower and taller than them.

## 0.2.1-beta

- Shield display: tiny shields no longer flicker the crescent. Absorbs under 25 points or 5% of your health, whichever is larger, are not drawn (a Paladin's Seal of Righteousness gives one of 10-20 points).
- The sound when a shield ends now plays (the old sound did not play on Forever). Choose it from nine sounds under its switch; choosing one plays it.
- Cooldown chimes: Dyre's Picks, nine new sounds, lead each chime's sound menu.
- With Dyre's Shields Up (formerly Shields Up Forever) also installed, you still see one display.

## 0.2.0-beta

- Every frame is magnetic: drop the conjure, portal, or Polymorph bar or a buff reminder near another and it snaps beside it, lined up. Shift-drag moves a snapped group. A drop that combat interrupts finishes when combat ends.
- Polymorph: clicking the bar to sheep the mob again now works in combat. It recasts on your focus first, the moon marker goes on even when the Polymorph lands in combat, and a recast never toggles the moon off. A cast on the mob under your mouse counts.
- New "! Polymorph" macro: focuses the mob under your mouse (or your target, out of combat) and sheeps your focus.
- Shield display: the timed crescents (Mana Shield, Paladin bubbles) now run out exactly when the shield ends, not a segment early. A Paladin's Blessing of Protection on you shows as a gold innermost crescent that drains with its time left, also in combat. With Warlock Tools Forever or Shields Up Forever also installed, you still see one display.

## 0.1.0-beta

- Conjure bar: Water, Food, and Mana Gem buttons. With no one targeted, left-click eats, drinks, or uses your best, and right-click conjures your best rank.
- Level-matched sharing: with a friendly player targeted, right-click conjures the best food or water they can use, and left-click trades them your share stack size of it (a setting, 10 by default, 1 to 20) or all you have if less, and whispers them. When someone opens a trade with you, the buttons serve them and put their share straight into the window. Middle-click always eats or drinks your own best.
- Food & Water button: trades a share of both in one click with one whisper, or eats and drinks your best; right-click conjures water and food in turn. A matching "! Food & Water" macro.
- Size settings for the conjure bar and the shield display (50-150%).
- Mana gems: left-click uses your best gem; right-click conjures the best one you don't carry. Before you learn Conjure Mana Agate, the button tells you when it comes.
- "! Water", "! Food", and "! Mana Gem" macros in your character macros for your action bars.
- Shield display: a segmented crescent beside your character that fills with your remaining Ice Barrier, Mana Shield, ward, or other shield (like Power Word: Shield), in the shield's color, with the amount, also in combat. It drops away the moment the shield is used up. With several shields up, it shows their total, with an icon for each shield that is up. Mana Shield, which has no absorb amount, drains with its time left in its own inner crescent. Optional sound when a shield ends.
- Cooldown chimes: a sound just before Blink, Frost Nova, Counterspell, Ice Block, Ice Barrier, Evocation, and other spells you pick are ready again, also in combat, with a sound of your choice for each spell, or a voice that says its name.
- Portal bar: a button for each teleport and portal you know, with your rune counts (never blocking a cast), a group message when you open a portal, and an emote when you teleport.
- Polymorph bar: the sheeped mob's name and the time left, a group message as you start casting ("Sheeping %T; you spank it, you tank it"), the moon marker when it lands, and a click to sheep the mob again.
- Buff reminders: an icon with a pulsing border for each buff you are missing out of combat (Arcane Intellect, also for your group, and your armor), each movable and resizable, snapping together like magnets (Shift-drag moves a snapped group). Click one to cast the buff: on you, then each group member who lacks it, or Arcane Brilliance for two or more.
- Announce settings page: turn each whisper and group message on or off and edit its text.
- While frames are unlocked, an alignment grid with the screen's center lines in red.
- Settings are saved per character.
