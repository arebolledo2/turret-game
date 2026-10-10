# Itemization and full-screen shop revamp

Status: proposed, 2026-10-10. Planning only; runtime and item balance are unchanged.

[Interactive layout study](shop-layout-study.html): illustrative SVG art and purchase previews; no live transactions.

## Confirmed direction

- Combat items target Projectile, AoE, Instant or Kinetic attacks rather than turret identities.
- Families overlap. Plasma benefits from Projectile and AoE items; Shock from Instant and AoE.
- Most items have fewer or no downsides. A minority can retain meaningful trade-offs.
- The shop fills the screen with an opaque background; the game and combat HUD are not visible behind it.
- Upgrade the SVG artwork substantially while retaining recognisable concepts.
- Remove visible category tags: TURRET, TALL, WIDE, ION, ELECTRIC, and equivalent family/category badges. Internal classification remains available to logic. Ordinary effect text can still name what an upgrade affects.

The numerical examples and migration choices below are recommendations for the first playable pass, not approved final balance.

## 1. Shared attack families

Use the existing attack-style metadata as the foundation. Internally, keep elemental `DamageType` separate: PHYSICAL, FIRE, ELECTRIC and PLASMA describe damage flavour, whereas the requested families describe delivery. Kinetic is the player-facing name for contact/melee attacks; it must not accidentally include every PHYSICAL attack.

| Turret | Proposed families | Notes |
|---|---|---|
| Ion | Projectile | Travelling direct shots |
| Plasma | Projectile + AoE | Travelling explosive shots |
| Shock | Instant + AoE | Immediate radial pulse; add missing Instant metadata |
| Tesla | Instant | Chain remains a capability, not a fifth prominent family |
| Melee | Kinetic | Contact sweep; hitting several enemies alone does not make it an AoE pulse |
| Sniper | Instant | Registry data exists, but it is not currently a supported shop turret; implementing it is a separate task |

Do not enable Sniper, Fire or Mine merely by changing classification. Future playable attacks declare their families and capabilities when their runtime exists.

Matching rules:

1. One modifier listing multiple families matches **any** listed family and applies once, even if a turret matches two.
2. Separate owned items stack using the existing additive-increase formula. Example: +10% Projectile damage and +10% AoE damage give Plasma +20%, before other modifiers, not +21%.
3. Family eligibility and mechanic support are distinct. A chain-count upgrade needs a chain-capable attack; a slow upgrade needs an existing slow or must explicitly grant one. No hidden no-op bonuses.
4. Preserve current OR semantics of legacy modifier filters while migrating. Add an explicit required-capability check, combined with the family match using AND; do not globally reinterpret all old filter fields.
5. Derived hits carry source attack families, source identity and relevant area values. Resolve damage modifiers once before delivery; do not reapply the same bonus on impact, splash or a derived proc.

## 2. Make upgrades feel rewarding

First-pass target: roughly 80% of the stocked pool has no explicit penalty. Common upgrades should be clean purchases. Keep trade-offs for clearly named specialist items where the choice changes play, rather than attaching a small tax to nearly every benefit.

Use price, rarity, effect strength and stack caps as the main balance controls. Start by removing modest penalties without also increasing every upside. Revisit powerful bonuses after mixed-family playtests.

| Current item | Proposed direction | Illustrative first pass |
|---|---|---|
| Polished Barrels | Projectile upgrade | +10% Projectile damage |
| Blast Charges | AoE upgrade | +12% area radius, +8% knockback; remove fire-rate penalty |
| Capacitor Bank | Instant upgrade | +8% Instant damage; remove range penalty |
| Weighted Bat → Counterweight | Kinetic upgrade | +12% Kinetic damage; remove spin penalty |
| Quick Loader | Broad upgrade | +7% attack cadence; remove damage penalty; define melee cadence through sweep speed, not its unused fire-rate stat |
| Dense Rounds | Projectile upgrade | +10% Projectile damage and +15% projectile speed, with no fire-rate penalty; distinguish from Polished Barrels by tier/price before stocking both |
| Four Doctrines | One upgrade per attack family | Start at +20% family damage, cap 2; remove penalties to other families |
| Hardpoint | Entrench specialist | Keep a smaller, readable carry-speed trade-off, provisionally -10% rather than -25% |
| Glass Cannon Core | Deliberate risky choice | Retain a clear hull-for-damage exchange; tune separately |
| Whirlwind Frame | Kinetic build upgrade | Keep its sweep/reach/slow identity; remove the -30% damage penalty to unrelated turrets |

These are examples, not the whole migration. Inventory every item reachable through `ShopCatalog`, including definitions inherited from older rarity files, feature-gated items, rewards and convoy items. Each row gets a new scope, supported mechanics, benefit, optional downside, cap, price, description and art assignment. Merge near-duplicates such as Faulty Wiring and Quick Loader or give them distinct jobs.

Support items for hull, economy, entrenchment, turret count and convoy remain useful. They do not need to be forced into one of the four combat families, and their internal roles are not shown as tags.

## 3. Resolve mechanics before broadening descriptions

The repository already has `AttackStyle` and modifier matching, but several effects are tied to named turrets or elements:

| Area | Current implementation | Proposed migration |
|---|---|---|
| Area radius | Plasma uses `aoe_radius`; Shock uses attack `range` as pulse radius | Add a shared area-size multiplier resolved once into the actual affected radius. Keep targeting range distinct where appropriate. Match visuals and damage boundaries. |
| Pierce | `Projectile3D` deliberately excludes splash shots | First pass: explicitly say “Direct projectiles pierce +1 enemy”, with a direct-projectile capability and eligibility preview. Explosive piercing is a later mechanic, not a silently promised benefit. |
| Chains and slows | Arc Rod/Superconductors filter Tesla/Shock IDs | Use chain and slow capabilities. Every named benefit lists which owned attacks can use it. Avoid inventing chains on every Instant attack. |
| Reactor Overload | Requires PLASMA damage and fetches stats for the literal `plasma` turret | Trigger from eligible AoE hits and use their source radius/damage snapshot. Preserve the chain-depth cap and attribution. |
| Storm Conductor | Checks the old Electric family on both neighbours | Convert to an Instant-attack adjacency benefit. Keep the distance requirement clear. |
| Kinetic cadence | Melee has `fire_rate = 0`, sweep speed and rehit delay | Family-specific bonuses use the actual stats. If a broad item says attack speed, adapt it deliberately to both firing and sweeping; do not modify an unused stat. |
| Diversity/mastery | Elemental Conduit and Mono-Type Mastery depend on old families/types | Convert mastery to an attack-family rule. For diversity, require distinct owned turrets assigned to distinct eligible families, maximum four, so one hybrid turret cannot claim two diversity slots. Reprice/rebalance the reward. |

Document direct-hit, splash and proc semantics together. A hybrid benefits from both families, but a single modifier must never apply twice merely because two tags matched. Separate items intentionally supporting that hybrid can both apply.

## 4. Full-screen refit screen

Visual direction: a polished Clockwork workshop dashboard. Deep opaque navy, teal focus states, brass trim and restrained coral accents connect the shop to the new models. Maintain high-contrast labels and generous artwork; decoration must not compete with effects or cost.

At normal widescreen sizes:

- Header: REFIT, upcoming wave, one scrap balance. No duplicated combat HUD.
- Main area, about 70% width: retain the current four offers initially—one turret and three items—using the extra space for richer art and clearer benefits.
- Right area, about 30%: owned turrets and installed items, with a selected-offer section showing exact benefit text and affected owned turrets. Show plain “No matching turret owned” for future-build purchases; do not hide the offer just because it does not fit yet.
- Footer: reroll, available repairs, and a prominent Deploy button in one predictable focus row. Preserve direct left/right navigation and skip unavailable actions.
- Card: large illustration, name, primary effect, any genuine drawback, cost, and sold/affordability state. **No category/tag label above the art or title.** Important rules and costs remain visible without hover.

Use an independent `ShopScreen` scene/controller rather than extending the shared refit/pause/end panel further. `GameHud` continues to own combat HUD; the app/arena presents the shop during SHOP. Reuse `ArenaShop` transactions and structured preview data. Pause, settings, game over and victory retain their own presentation and focus restoration.

The shop background is fully opaque and covers every aspect ratio; hide combat HUD, minimap, banners and hints while shopping. Suspend the 3D viewport's drawing during the shop if the viewport ownership permits it, restoring it on exit. Do not rely on an alpha overlay or merely blur the arena. Preserve the existing wave/shop simulation rules.

Responsive requirements: 16:9, 16:10 and ultrawide use the same screen edges with a bounded content width. At smaller widths use a 2×2 offer layout and a reachable build/details panel. Test at 1280×720 before raising minimum sizes. Keyboard, D-pad and stick focus all expose the same information; bought cards preserve their slots and hand focus to a valid control.

## 5. Upgrade the art, not just its resolution

Current `UiIcons` rasterizes every 24-unit SVG to a 64-pixel white texture, then tints it. OfferCard displays that in a larger tile. That is suitable for small functional symbols but limits prominent item art.

Create two separate asset uses:

| Use | Art standard |
|---|---|
| Stat, action and navigation symbols | Crisp compact SVGs, consistent weight and optical alignment; raster size follows display size/UI scale and is cached |
| Item illustrations | Dedicated full-colour SVG artwork authored around 256×256, rasterized appropriately for the actual screen; three-quarter objects, strong silhouettes, bevels, enamel panels, metal fittings, controlled shadows and highlights |
| Turret portraits | Consistent pre-rendered thumbnails of the actual Clockwork models; no need to substitute a generic power-button glyph for a recognisable turret |

Preserve the recognisable magnet, barrel, capacitor and mechanical-weight concepts. Avoid tiny ornamental detail that disappears on cards. Retain full colour instead of tinting the whole illustration purple. Express rarity subtly through the frame or small accent, while family eligibility lives in descriptive text and the purchase preview, not badges.

First art review: finish six representative examples—one turret portrait and five distinct item silhouettes—at final card size and small installed-item size. Approve that standard before producing the whole catalog. Prefer separate curated SVG assets for item art; keep small utility glyphs in the existing shared icon system. Use Godot-supported SVG features and inspect the engine import rather than trusting the browser alone.

## 6. Make shop information truthful

The current “TOTAL DPS” sums damage × fire rate. Melee has zero fire rate, and splash, chains and conditional effects are not represented adequately. Replace that headline with “Build overview”; show comparable per-attack damage/rate/reach on individual turrets, plus an explicit effects preview. Do not present an incomplete estimate as total combat DPS.

Add semantic stat names and units to preview data: area radius is not targeting range; knockback is not damage; spin speed is not shots per second. A selected item should explain which owned turrets change, and a special effect should show its rule even if it cannot be reduced to one number.

Fix sign semantics too: lower purchase penalty, reroll cost or rehit delay is a benefit. In the current screenshot Mass Production's reduced purchase penalty appears red alongside its actual damage penalty. Colour, wording and sign need to agree, with words/symbols providing meaning without colour alone.

Keep previews side-effect free. Test the numbers against the actual purchase, including hybrid matches and conditional items. Distinguish static numbers from situational rules instead of guessing their contribution.

## 7. Delivery sequence and acceptance

1. **Freeze taxonomy and migration sheet.** Implement the mapping table and matching contract; inventory all stocked items. Set the initial no-penalty majority and deliberate exceptions. Keep stable IDs for items that retain identity; explicitly map renamed/replaced IDs used by presets or tests.
2. **Produce the shop/art vertical slice.** Full-screen screen with four representative offers, one finished turret portrait, upgraded item SVGs, selected-offer details, and controller navigation. The accompanying HTML is a layout study only, not the target implementation or final art.
3. **Migrate modifiers and mechanics.** Replace old family/type dependencies in stats and runtime hooks, propagate attack context through hits, and resolve radius/cadence/capability semantics. Update descriptions and previews in the same change as each effect.
4. **Complete the catalog and art.** Apply the reviewed visual standard to all stocked offers, rework redundant items and the minority of trade-offs, and preserve rarity/stack/mode gates.
5. **Validate and tune.** Run GUT and resource checks; compare fixed-seed single-family and hybrid builds at equivalent scrap spend. Check early/mid/late waves and core/convoy variants. Human playtesting decides whether purchases feel rewarding. Change economy or wave difficulty only after observing the new item pool.

Acceptance criteria:

- No stocked combat item depends on a turret ID or old Ion/Plasma/Electric family membership to determine eligibility; capability restrictions are explicit and descriptive.
- Overlapping-family modifiers apply once each, with expected additive stacking; proc chains do not rescale damage repeatedly and respect depth limits.
- Every effect changes a supported stat/behaviour, or clearly states its capability requirement. Item scope, preview and actual gameplay agree.
- The common pool is predominantly positive; all retained penalties are deliberate and visible. Hybrid builds do not silently receive old “other turret” penalties.
- All shop-facing tags are absent, including offer headings, installed-item summaries and tooltips. Natural-language scope remains understandable.
- No arena or combat HUD is visible at any supported screen size; shop exit restores the game correctly.
- All offers, repairs, reroll, item details and Deploy are reachable with controller only. Focus survives purchases, rerolls, disabled controls, settings and shop exit.
- New SVGs remain crisp at target sizes in Godot and have distinct silhouettes; selected, unaffordable and sold states stay readable.
- Existing progression, transactions, core/convoy rules and feature-gate tests pass alongside the new scope and preview tests.

## Implementation map

- Taxonomy: `scripts/data/game_enums.gd`, `scripts/registries/turret_registry.gd`.
- Catalog/content: `scripts/registries/items/items_v2.gd`, inherited rarity files, `scripts/registries/item_registry.gd`, `scripts/data/shop_catalog.gd`.
- Matching/stats: `scripts/systems/modifier_system.gd`, `scripts/autoload/turret_stats_service.gd`, special-effect handlers discovered during the item inventory.
- Combat consumers: `scripts/game/turret_actor.gd`, `projectile_3d.gd`, `combat_shot_3d.gd`, `combat_hit_3d.gd`, `blast_effects.gd`.
- Shop/presentation: `scripts/game/arena_shop.gd`, `shop_view_data.gd`, `game_hud.gd`, `scripts/ui/offer_card.gd`, `build_panel.gd`, `ui_icons.gd`; new dedicated shop scene and illustration assets.
- Documentation: update `doc/items.md`, `doc/ui.md`, gameplay and catalog references when implemented. Several older docs describe a smaller/older feature set; use code/catalog as the inventory source.

Open tuning choices: exact catalog values, which rare items retain costs, and how strong hybrid specialization should be. These do not block the taxonomy and visual prototype. Overlapping families and removal of visible tags are confirmed.
