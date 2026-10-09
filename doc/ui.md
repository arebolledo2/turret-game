# User interface

`GameApp` in `scripts/game/game_app.gd` builds the default start screen: Play, Settings and Quit, plus current controls and supported mode. Play receives initial focus. Keyboard arrows/Enter and controller directional input/A navigate menus; Escape or controller B returns from settings.

## Settings

Fullscreen, VSync, Reduced motion and Sound effects volume apply immediately and persist in `user://game_preferences.cfg` through `SettingsService`. Display operations are skipped in headless runs. Reduced motion removes model bobbing, recoil and hit blinking; combat warnings and effect ranges remain visible. Sound effects default to 70%; zero mutes the SFX bus. Legacy 2D debugging features remain unexposed.

## In-game presentation

`scripts/game/game_hud.gd` is a CanvasLayer presentation adapter for `ArenaWorld`. It shows three corner clusters (hull and core `VitalBar`s, wave pips with the timer, scrap), a short "WAVE n" banner while a wave is announced, and the game's message / Entrench / ground readouts bottom-left. Refit shows four `OfferCard`s (icon, name, stat chips, cost; description on focus), reroll, repair and Deploy. Hovering or focusing a card previews the build after buying it. Pause/end panels show the current build; Main Menu tears down the run.

Shared UI pieces live in `scripts/ui/`: `UiPalette` (colours, one hue per stat), `ChamferStyle` (the cut-corner StyleBox), `UiIcons`/`UiIconData` (SVG icon fragments rasterised at runtime; add an icon by adding a dictionary entry), `SegmentedBar`, `StatChip`, `StatTile`, `IconButton`, `OfferCard`, `BuildPanel` and `VitalBar`. `ShopViewData` (`scripts/game/`) turns shop and build state into the structured data those controls draw; its `preview()` measures an item by briefly adding its modifiers to `ModifierService`, so the numbers match what a purchase does. The theme font is Barlow Condensed, with Share Tech Mono (`Numeral` variation) for digits. Escape/controller Start toggles pause. End states support the restart button or R. Dev builds add an overlay panel (F1, or Back plus right-stick click on a controller) described in [dev tools](dev-tools.md); the HUD hides its pause panel while it is open.

The project uses the shared theme and a 1920×1080 reference canvas with canvas-item stretching. App screens and game panels were inspected at 1280×720. Focus is refreshed on phase changes, and controller navigation is exercised using real InputEvent dispatch in integration tests. Physical controller testing remains a human playtest step.

Native screenshots can be generated with `res://tools/capture_app.tscn`, which captures start, settings, pause, defeat, victory and return-to-menu screens. `res://tools/capture_game.tscn` provides refit, staged combat and stress captures. Both write under ignored `.test-results/`.
