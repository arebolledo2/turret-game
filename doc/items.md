# Items and attack families

The full-screen Shop stocks one turret and three items. The 54-item catalog is defined in `scripts/registries/items/items_v3.gd`, overriding the legacy definitions by stable ID. See the [original migration and balance table](plans/item-migration.md) and [eleven implemented expansion items](plans/new-item-concepts.md). There are 13 Common, 19 Uncommon, 12 Rare, 8 Epic and 2 Legendary entries, including the three Convoy-only items.

## Eligibility

Combat modifiers use `filter.attack_family`, distinct from elemental `DamageType`:

| Turret | Attack families |
|---|---|
| Ion | Projectile |
| Plasma | Projectile, AoE |
| Shock | Instant, AoE |
| Tesla | Instant |
| Melee | Kinetic |
| Sniper (registry only, not stocked) | Instant |

One modifier matches any listed family and applies once. Separate percentage increases add: +10% Projectile and +20% AoE damage give Plasma +30%, before separate multiplicative effects. Kinetic means contact/melee, not every PHYSICAL attack.

`filter.requires` adds capability checks with AND semantics. Direct-projectile piercing excludes splash shots; chain upgrades require chaining, and existing-slow upgrades require a base slow. Legacy filters retain their old matching semantics for non-stocked content. Every stocked combat item uses the new families rather than turret identities.

## Mechanics

- `attack_speed` scales both shot frequency and melee sweep speed; melee does not gain an unused firing bonus.
- `area_size` scales Plasma splash and Shock pulse radius. Shock's actual hit boundary and range display use the expanded radius; Plasma targeting range stays separate.
- Reactor Overload triggers from AoE kills, including Shock, for 40% of resolved killing damage at 60% of the source area radius. Source identity/families/radius propagate; each derived damage is scaled once. Chains stop at depth 3.
- Resonance Link (stable ID `storm_conductor`) grants +35% damage to Instant turrets within 4 m of another Instant turret.
- Last Stand grants +40% firing/sweep speed below 30% hull.
- Focused Arsenal (`mono_type_mastery`) requires all owned turrets to share at least one attack family; it grants +50% damage and +25% attack speed.
- Combined Arms (`elemental_conduit`) grants +12% damage per distinct family represented by a separate owned turret, maximum +48%. One hybrid cannot occupy two slots; two owned hybrids can represent different families.
- Army Doctrine grants +3% attack speed per turret beyond the third, capped at +30%.
- Return Spring (`killzone_bat`) reduces contact rehit delay. Whirlwind Frame grants a Kinetic slow and increases sweep/reach.
- Entrench, hull, economy and Convoy items remain support upgrades. Combined purchase-penalty reductions stop at zero.

47/54 items have no explicit downside. The minority of trade-offs are stated in the always-visible effect text. Prices, rarity and stack caps carry most of the balance burden. Exact values are a first playable pass, not a claim of completed balance testing.

## Shop and previews

The opaque `ShopScreen` hides the arena and combat HUD, suspends 3D drawing while active, and restores it on exit. It shows full-colour SVG item illustrations and portraits of the actual Clockwork models. Category tags are absent from cards, details and installed-item summaries. Rarity uses a restrained border accent.

`ShopViewData.preview()` synchronously evaluates the shared stat resolver, including static ownership conditions, then restores counts/modifiers. It does not purchase, emit changes or consume RNG. Changed turret values show before/after numbers with units, plus affected owned turrets. Situational effects show their rule without pretending to be permanently active. There is no aggregate “Total DPS” claim.

## Gates and authoring

`ShopCatalog` remains the stock/reward authority. The existing `items_v2` and `items_v2_hooks` flags still gate their original IDs; turning them off removes those items rather than restoring old balance. `mode_convoy` items additionally require Convoy mode. Sniper and Mine remain outside supported shop content; Flamethrower, Bow and Bowling are stocked. Reserve Battery additionally requires a core mode.

To add an item, add a reviewed row to ItemsV3, a catalog entry and supported family/capability filters. Provide a separate `assets/ui/items/<id>.svg`, a clear description and appropriate rarity/stack cap. Add tests for actual stat or combat behaviour and preview equivalence. New stats require a runtime consumer.

Art tooling: `python tools/build_shop_art.py` rebuilds the full-colour SVG set from curated shapes and the layout-study motifs; `res://tools/render_shop_portraits.tscn` renders the five model portraits with a graphics driver. Run an editor import after regenerating. `res://tools/export_shop_catalog.tscn` writes an audit JSON under `.test-results/`.

## Situational buff display

Nearby turret inspection and the range toggle show active item icons with stack counts and duration strips. Hero buffs appear above the hero. This includes Follow-Through, Victory Lap, Rescue Beacon, Close Partnership, Last Stand, Resonance Link and Entrenchment. See the [expansion rules](plans/new-item-concepts.md) for trigger and reset behaviour.

Convoy greed: **Heavy Hauler** slows the core by 20% and increases kill scrap by 15% (Uncommon, up to two stacks). Longer journeys receive proportionally more enemy groups without a duration-scaling cap. See [moving-core routes](enemy-ecology.md#moving-core-routes-and-greed).
