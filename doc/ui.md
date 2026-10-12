# User interface

`GameApp` in `scripts/game/game_app.gd` builds the default start screen: wordmark, chips for the chosen waves/difficulty/mode, Play, Settings, Quit and the difficulty and mode selectors. There is no controls screen. Play receives initial focus. Keyboard arrows/Enter and controller directional input/A navigate menus; Escape or controller B returns from settings.

## Settings

Fullscreen, VSync, Reduced motion and Sound effects volume apply immediately and persist in `user://game_preferences.cfg` through `SettingsService`. Display operations are skipped in headless runs. Reduced motion removes model bobbing, recoil and hit blinking; combat warnings and effect ranges remain visible. Sound effects default to 70%; zero mutes the SFX bus. Legacy 2D debugging features remain unexposed.

## In-game presentation

`scripts/game/game_hud.gd` is a CanvasLayer presentation adapter for `ArenaWorld`. It shows three corner clusters (hull and core `VitalBar`s, wave pips with the timer, scrap), a short "WAVE n" banner while a wave is announced, and the game's message / Entrench / ground readouts bottom-left. The independent `ShopScreen` scene fills the screen with opaque navy, hides the combat HUD and suspends viewport 3D rendering while open. Four `OfferCard`s show full-colour artwork, name, always-visible effect text and cost, without category tags. Reroll, repairs and Deploy form an explicit controller focus row that skips unavailable repairs. Sold cards retain their slots and hand focus to another offer or Deploy. The scrollable sidebar shows the build, purchase previews and inspectable installed upgrades. Pause and end panels show a summary (wave strip with the failed wave in red, a reason chip on defeat, and waves/kills/scrap/time tiles) beside the current build; Main Menu tears down the run.

Shared UI pieces live in `scripts/ui/`: `UiPalette` (colours, one hue per stat), `ChamferStyle` (the cut-corner StyleBox), `UiIcons`/`UiIconData` (compact utility glyphs rasterised at 128 pixels), `ShopArt` (cached full-colour 384-pixel item SVGs and 512-pixel model portraits), `SegmentedBar`, `StatChip`, `StatTile`, `IconButton`, `OfferCard`, `BuildPanel` and `VitalBar`. `ShopViewData` (`scripts/game/`) turns shop and build state into the structured data those controls draw; its `preview()` measures an item by synchronously adding its modifiers and simulating ownership, then restoring both, so the numbers match what a purchase does. The theme font is Barlow Condensed, with Share Tech Mono (`Numeral` variation) for digits. Escape/controller Start toggles pause. End states support the restart button or R. Dev builds add an overlay panel (F1, or Back plus right-stick click on a controller) described in [dev tools](dev-tools.md); the HUD hides its pause panel while it is open.

The project uses the shared theme and a 1920×1080 reference canvas with canvas-item stretching. App screens and game panels were inspected at 1280×720. Focus is refreshed on phase changes, and controller navigation is exercised using real InputEvent dispatch in integration tests. Physical controller testing remains a human playtest step.

Native screenshots can be generated with `res://tools/capture_app.tscn`, which captures start, settings, pause, defeat, victory and return-to-menu screens. `res://tools/capture_game.tscn` provides shop, staged combat and stress captures. Both write under ignored `.test-results/`.

`res://tools/preview_shop.tscn` creates a deterministic Shop review at any window resolution and saves `.test-results/shop-WIDTHxHEIGHT.png`. The 1920×1080 reference canvas scales down to 1280×720; narrower logical canvases use two offer columns. Both offer/build scroll containers follow controller focus. Category tags and the misleading aggregate DPS tile are removed.

## Turret inspection and salvage recap

The full-screen Shop has **Offers** and **Turrets** tabs. Q/E or controller LB/RB switches tabs. Turrets lists each owned instance by stable ID; select one for its illustration, level, XP bar, resolved combat stats, entrenchment, most recent salvage award and evolution milestones. The mouse wheel or right stick scrolls detailed information. Footer repair and Deploy controls remain accessible on either tab. Form evolutions are still pending.

Before Shop, a short wave-end sequence shows collected salvage flying toward assigned turrets, filling XP bars and celebrating level gains with damage comparisons. The recap waits for A/Space/Continue, which can also skip the animation without forfeiting rewards; Reduced Motion keeps the count-up but removes flights and pulses.

XP presentation uses a shared high-contrast `TurretXpBar`: large meters in the salvage recap and selected turret details, plus compact meters on every Turrets roster button. Current/next level labels lead; exact XP totals remain available in detailed inspection.

Turret offer cards and the Turrets inspector show icon-and-text attack-family badges (Projectile, AoE, Instant, Kinetic). `AttackFamilyBadges` reads `TurretRegistry.get_attack_families`, the same overlapping families used for item eligibility. Item cards keep their effect descriptions without legacy category tags.

Shop offers can be locked for free using the card lock button, controller X or keyboard L. Locks preserve the offer, slot and quoted price through rerolls and wave transitions, including turret offers. Unlocking restores current pricing. Buying consumes the lock; restarting clears stock. Reroll is disabled when every offer is locked. Unlocked stock retains normal reroll costs and pricing.

Lock controls sit outside and below each card, display LOCK / UNLOCK and participate in controller focus: Down from an offer enters its lock button; left/right moves between locks, Up returns to the offer, and Down proceeds to the next offer row or nearest enabled footer action. Footer Up returns to the nearest available lock. Horizontal navigation stays within each visual row, and purchasing advances focus to the next available offer. A activates the lock independently of purchasing.

Item offers show registry rarity through their name and border colors, plus a text label: Common white, Uncommon green, Rare blue, Epic purple, Legendary orange, Unique red. Focus retains its teal outline. Item SVG artwork contains no variant-count dots; rarity comes from ItemRegistry rather than the illustration.


Preparation offers Auto Deploy (Y / F), off by default and saved between launches. Enabling it arranges immediately; subsequent preparation phases arrange again. It never starts combat and manual adjustments remain available. One turret guards each spawn zone from its centre when unrestricted, or outside its boundary when spawn placement is restricted, then remaining turrets spread along the convoy route or around the stationary core/map centre. All placements respect terrain, edges, core clearance and turret spacing. Moving resets entrenchment.

The optional Restrict Spawn Zone Placement user feature flag (F1 developer panel) defaults off. When enabled, deployment rejects positions within the zone radius plus turret clearance, including combat drops. Existing turrets inside newly generated zones must be moved before starting combat; Auto Deploy can clear them. Auto Deploy uses zone centres when this toggle is off, falling back to nearby valid ground if a centre is obstructed.
