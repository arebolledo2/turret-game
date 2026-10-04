# User interface

`GameApp` in `scripts/game/game_app.gd` builds the default start screen: Play, Settings and Quit, plus current controls and supported mode. Play receives initial focus. Keyboard arrows/Enter and controller directional input/A navigate menus; Escape or controller B returns from settings.

## Settings

Fullscreen, VSync, Reduced motion and Sound effects volume apply immediately and persist in `user://game_preferences.cfg` through `SettingsService`. Display operations are skipped in headless runs. Reduced motion removes model bobbing, recoil and hit blinking; combat warnings and effect ranges remain visible. Sound effects default to 70%; zero mutes the SFX bus. Legacy 2D debugging features remain unexposed.

## In-game presentation

`scripts/game/game_hud.gd` is a CanvasLayer presentation adapter for `ArenaWorld`. It displays hull, wave/time, scrap, kills and contextual controls. Refit shows four supported offers, reroll, repair and Continue. Pause/end panels show the current turret/item/player build; Main Menu tears down the run. Escape/controller Start toggles pause. End states support the restart button or R. Dev builds add an overlay panel (F1, or Back plus right-stick click on a controller) described in [dev tools](dev-tools.md); the HUD hides its pause panel while it is open.

The project uses the shared theme and a 1920×1080 reference canvas with canvas-item stretching. App screens and game panels were inspected at 1280×720. Focus is refreshed on phase changes, and controller navigation is exercised using real InputEvent dispatch in integration tests. Physical controller testing remains a human playtest step.

Native screenshots can be generated with `res://tools/capture_app.tscn`, which captures start, settings, pause, defeat, victory and return-to-menu screens. `res://tools/capture_game.tscn` provides refit, staged combat and stress captures. Both write under ignored `.test-results/`.
