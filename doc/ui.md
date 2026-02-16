# UI Architecture

## Overview

UI components are organized by function into HUD elements, full-screen menus, shop panels, and display overlays. The font system uses centralized semantic sizing via Theme Variations. Dynamic scaling ensures UI works across different resolutions.

## Core HUD

In-game heads-up display during combat:

- **HUDGameDisplay** — Shows player health, current wave number, and scrap count
- **HUDMenuManager** — Manages HUD menu states and transitions between UI overlays

Main HUD script: `scripts/hud.gd`

## Screens

Full-screen UI states for game flow:

| Screen | Purpose |
| --- | --- |
| StartSettings | Initial game launch settings |
| DifficultySelect | Difficulty level selection |
| GameModeSelect | Game mode selection |
| WaveAnnouncement | Brief wave number display before combat |
| PauseMenu | In-game pause menu |
| GameOverScreen | End-of-game results display |
| SettingsMenu | Runtime settings adjustment |
| LootReviewScreen | Post-wave item review and collection |

## Shop Components

Shop UI during the SHOP game state:

- **ShopOffersPanel** — Displays available items and turrets for purchase
- **TechTreePanel** — Tech tree visualization with node connections
- **TechNodeButton** — Individual tech node interaction button

**Shop Tabs:**
- **EconomyTab** — Scrap balance and purchase history
- **PlayerTab** — Player stats and equipped items
- **ItemsTab** — Item inventory and details
- **TurretsTab** — Turret inventory and management

## Display Panels

Contextual information overlays during gameplay:

- **TurretDisplayUI** — Turret stats and info when hovering/selecting turrets
- **ItemDisplayUI** — Item details and effects display
- **BuildDisplayUI** — Turret placement preview and constraints
- **DefenseTargetHP** — Health bar for DefenseTarget entity (Tech Defense / Escort modes)
- **TunnelDoorProgress** — Progress indicator for TunnelDoor breaching (Tunneling mode)

## Utilities

Shared UI infrastructure:

- **UIHelpers** — Common UI utility functions
- **ScalableUIPanel** — Base panel with dynamic scaling support
- **InventoryPanel** — Reusable inventory display component
- **StatsPanel** — Reusable stats display component
- **OffScreenIndicators** — UI layer for off-screen entity tracking arrows

## Font System

Centralized font sizing using the **FontSizes** service (`scripts/autoload/font_sizes.gd`).

UI components use semantic **Theme Variations** instead of manual size overrides:

| Variation | Use Case |
| --- | --- |
| Header1 | Primary headings |
| Header2 | Secondary headings |
| Header3 | Section headings |
| Header4 | Sub-section headings |
| Body | Standard body text |
| BodySmall | Compact text |
| ButtonLarge | Large action buttons |

The **UIScaler** service (`scripts/autoload/ui_scaler.gd`) coordinates with FontSizes to dynamically adjust all UI proportions based on screen resolution and scaling settings.

## UI Scripts Location

- HUD and screens: `scripts/hud.gd`, `scripts/ui/`
- UI utilities: `scripts/ui/`
- Font management: `scripts/autoload/font_sizes.gd`
- UI scaling: `scripts/autoload/ui_scaler.gd`
- Off-screen indicators: `scripts/autoload/off_screen_indicator_service.gd`
