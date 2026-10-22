# Changelog

Player-facing changes for each Mage Tools Forever release, newest first. The
release builder copies the section for the TOC version into the GitHub release
notes and the CurseForge changelog, and fails if that section is missing.

## 1.1.2

### Other changes

- Size sliders are labeled without '(%)': their values already show the % sign.

## 1.1.1

### Fixes

- The shield display grows and shrinks around its middle and stays where you put it; its number and icons keep their size.

## 1.1.0

### Features

- The Polymorph bar has new settings on the Polymorph settings page: **Bar width**, **Bar height**, **Text size**, and **Opacity**, each with a gold mark at its default, and a **Reset size** button. The defaults keep the bar as it was, and **Bar size (%)** still scales it on top. Opacity fades the whole bar at once, also in combat; a size change made in combat applies when combat ends.
- **Bar size (%)** on the Conjure, Portals, and Polymorph pages has a gold mark at 100%.

### Fixes

- The conjure, portal, and Polymorph bars and the buff reminders now grow and shrink around their middle and stay where you put them. Before, a bigger **Bar size** moved a bar right and up, and a smaller one moved it left and down. The portal bar also stays centered when you learn a new teleport or portal.

### Other changes

- Mage Tools Forever now needs **Dyre's Toolkit 2.0** (the CurseForge app installs it). The toolkit moves, snaps, and sizes every MTF frame, the same way for all of Dyre's AddOns. Your frames keep their places and sizes. Without Dyre's Toolkit 2.0, MTF stays off and says once in chat what to install.

## 1.0.0

The first full release for WoW: Forever, no longer marked beta: it was play tested on the Forever beta client 1.60.1, build 70450. CurseForge now offers it as a release, so the app updates it and installs what it needs for every player.

- The CurseForge app installs Dyre's Toolkit and Dyre's Sounds with it.

## 0.3.3-beta

- Fixed: a Polymorph no longer brings up the game's "MageToolsForever has been blocked from an action" popup or a "protected function" error. The game does not let AddOns set raid markers, so MTF no longer marks by itself.
- For the moon marker, use the **"! Polymorph"** macro or click the Polymorph bar: they mark the mob with `/tm` as you press them, also in combat, and a second press never toggles the moon off. A Polymorph from the plain spell button gets no moon. MTF updates your "! Polymorph" macro out of combat. The "Mark the sheep with the moon" switch now adds or removes the `/tm` line in the macro and the bar's click.
- MTF's macros ("! Water", "! Food", "! Food & Water", "! Mana Gem", "! Polymorph") and the Polymorph bar's click now use `/use` instead of `/cast`, so they are shorter, and every `@focus` check also checks that you have a focus. MTF updates your macros out of combat.
- Fixed: the Polymorph bar's spot no longer catches your clicks when no bar shows. It takes clicks only while it shows a sheep to click again, or while frames are unlocked.

- Mage Tools Forever works with **Dyre's Toolkit**, a small AddOn that all of Dyre's AddOns share. The CurseForge app installs it with Mage Tools Forever.
- With Dyre's Toolkit, MTF's settings are under **Options > AddOns > Dyre's AddOns > Mage Tools Forever**, and MTF is listed under Dyre's Toolkit in the AddOn list.
- With Dyre's Toolkit, `/mtf unlock`, `/mtf lock`, and MTF's unlock switch unlock and lock the frames of every Dyre's AddOn together, frames snap to the frames of your other Dyre's AddOns, and the toolkit draws the grid (with its own "Snap to the grid"). The shield display snaps with the other frames too.
- With Dyre's Toolkit, MTF's settings no longer have their own "Unlock frames to move them" and grid switches: use the **Unlock frames** switch and the grid settings on the Dyre's AddOns page, `/dyre unlock`, the minimap button, or `/mtf unlock` and `/mtf lock`.
- Without Dyre's Toolkit, MTF works as before and says once in chat to install it.

## 0.3.2-beta

- With **Dyre's Buff Reminders** installed, MTF plays no cooldown chimes: Dyre's Buff Reminders plays them, so you never hear two, and on its first run it copies your MTF chime settings. MTF's chime settings are greyed out and point you to `/dbr`, and MTF keeps them as they are.

## 0.3.1-beta

- The Shield, Buff Reminders, and Cooldown Chimes settings pages say when one of Dyre's AddOns runs that feature: the name in the settings list names it, and a heading at the top says so.
- With **Dyre's Shields Up** installed, MTF leaves the shield display to it: MTF draws no ring of its own, and its shield settings are greyed out and point you to `/dsu`. Your MTF shield settings stay as they are.

## 0.3.0-beta

- With **Dyre's Buff Reminders** installed, MTF hides its own buff reminders, so you never see two icons for one buff. Your reminder settings in MTF stay as they are.
- Sounds now come from Dyre's Sounds, a small library AddOn that all of Dyre's AddOns share, so your computer keeps one copy of the sound files instead of several. The CurseForge app installs it with Mage Tools Forever; otherwise get it from CurseForge or github.com/jbedworth/DyresSounds.
- Without Dyre's Sounds, Mage Tools Forever plays no sounds (no cooldown chimes and no sound when a shield ends) and says so once in chat. Everything else works as before.
- The sound you chose for the end of a shield stays your choice, and so does each chime's sound.
- With Dyre's Cooldown Chimes installed, Mage Tools Forever plays no chimes: Dyre's Cooldown Chimes plays them, and on its first run it copies your MTF chime settings. MTF keeps its own chime settings as they are, and its Cooldown Chimes page says that Dyre's Cooldown Chimes plays them.

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
