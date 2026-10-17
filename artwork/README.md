# Mage Tools Forever artwork

Publishing images for project pages and distribution listings (CurseForge
screenshots and the like). Keep this directory out of the runtime release
ZIP; the TOC uses a built-in client icon.

## Logo

Original vector artwork: an arcane sigil, a glowing blue four-pointed star
edged in gold with four shorter points between, a bright arcane orb at its
heart, inside a rune-marked ring, on a rich dark-brown background. It shares
its frame and colors with the Weapon Sets Forever, Weapon Skills Forever, and
Warlock Tools Forever logos. The design has no font or external-image
dependencies.

- `mage-tools-forever-logo.svg`: editable, resolution-independent source.
- `mage-tools-forever-logo.png`: 1024 x 1024 PNG master.
- `mage-tools-forever-logo-512.png`: 512 x 512 PNG for square project images.

The PNGs are rendered from the SVG with headless Chrome, for example:

```sh
chrome --headless=new --hide-scrollbars --window-size=1024,1024 --force-device-scale-factor=0.5 --screenshot=mage-tools-forever-logo-512.png mage-tools-forever-logo.svg
```

## Screenshots

In-game captures by the author on the Forever beta client, saved as PNG:

- `screenshots/shield-display.png`: the shield display with its crescents,
  absorb amount, and shield icons.
- `screenshots/conjure-bar.png`: the conjure bar with Water, Food, Food &
  Water, and Mana Gem buttons.
- `screenshots/portal-bar.png`: the portal bar, with rune counts.
- `screenshots/polymorph-bar.png`: the Polymorph bar on a sheeped mob, with
  its time left.
- `screenshots/unlocked-grid.png`: `/mtf unlock`: the alignment grid with
  its red center lines, the frames outlined to drag, and the Polymorph bar
  and buff reminders as samples.
- `screenshots/settings-main.png`: the main settings page, one switch per
  tool, the frame lock, and the grid switch.
- `screenshots/settings-conjure.png`: the Conjure settings page.
- `screenshots/settings-shield.png`: the Shield settings page.
- `screenshots/settings-chimes-sounds.png`: the Cooldown Chimes page with a
  chime's nested sound menu open.
- `screenshots/settings-announce.png`: the Announce page, each message's
  switch and editable text.

Retake a screenshot when the feature it shows changes visibly.

This artwork is covered by the repository's MIT License. Copyright (c) 2026
John Bedworth. Include the applicable license notice with distributed copies.
