class_name GameEnums
extends RefCounted

## All game enumerations in one place for easy reference and type safety

# Difficulty levels for the game
enum Difficulty {EASY, MEDIUM, HARD, BRUTAL}

# Attack style tags - how damage is delivered
enum AttackStyle {PROJECTILE, INSTANT, AOE, CHAIN, MELEE, DEPLOYABLE}

# Damage type tags - elemental classification
enum DamageType {PHYSICAL, FIRE, ELECTRIC, PLASMA}

# Enemy rank - scaling and reward tiers
enum EnemyRank {NORMAL, LIEUTENANT, CAPTAIN}

# Item rarity levels
enum ItemRarity {COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, UNIQUE}
