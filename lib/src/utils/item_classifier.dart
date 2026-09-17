/// Categories for collected rewards and drops in Astra Lawnchair telemetry.
enum ItemCategory {
  trinity('Trinity Trials & Gear'),
  ammo('Ammunition & Rockets'),
  resource('Resources & Minerals'),
  other('Other Collected Items');

  final String label;
  const ItemCategory(this.label);
}

/// Classifier utility matching dropped items against known DarkOrbit equipment,
/// ammo, resources, and Trinity Trials items.
class ItemClassifier {
  // Common ammo and laser identifiers (normalized lowercase without spaces or hyphens)
  static final Set<String> _knownAmmoNormalized = {
    // Lasers
    'ucb100',
    'rsb75',
    'lcb10',
    'mcb25',
    'mcb50',
    'sab50',
    'cbo100',
    'job100',
    'rb214',
    'pib100',
    'rcb140',
    'idb125',
    'vb142',
    'emaa20',
    'emma20',
    'sbl100',
    'abl',
    // Rockets
    'r310',
    'plt2026',
    'plt2021',
    'plt3030',
    'bdr1211',
    'bdr1212',
    'sp100x',
    'agt500',
    'dcr250',
    'pld8',
    'ric3',
    'rc100',
    'sr5',
    'k300m',
    'wizx',
    // Multi-Rockets
    'hstrm01',
    'ubr100',
    'eco10',
    'sar01',
    'sar02',
    'cbr',
  };

  // Known resources & minerals
  static final Set<String> _knownResourcesNormalized = {
    // Ores & Skylab
    'prometium',
    'endurium',
    'terbium',
    'prometid',
    'duranium',
    'promerium',
    'seprom',
    'xenomit',
    'palladium',
    'osmium',
    // Crafting & Alien Drops
    'mucosum',
    'scrap',
    'prismatium',
    'plasmide',
    'aurus',
    'bifenon',
    'tetrathrin',
    'kyhalon',
    'hybridalloy',
    'indoctrineoil',
    'indoctrineaccelerator',
    'rinusk',
    'blacklighttrace',
    'blacklightshard',
    'mindfirecerebrum',
    'eternalfragment',
    'axionbeamregulator',
    'schismcrystal',
    'solidus',
    'diametrion',
    'polychromium',
    'astralite',
    'atlasshard',
    'luminium',
    'darksilvercoin',
    // Hardware & Components
    'highfrequencycable',
    'nanocase',
    'prismaticsocket',
    'nanocondenser',
    'hybridprocessor',
    'microtransistors',
    'isochronate',
    'hydraalloy',
    'neptunealloy',
    'triskelionalloy',
    // Vouchers, Keys, & Event Tokens
    'logdisk',
    'logdisks',
    'bootykey',
    'greenbootykey',
    'redbootykey',
    'bluebootykey',
    'blackbootykey',
    'apocalypsebootykey',
    'obsidianbootykey',
    'prometheusbootykey',
    'repairvoucher',
    'jumpvoucher',
    'primecoupon',
    'permit',
    'permitplus',
    'unstableshard',
    'salvagecore',
    'evocationchip',
    'neuchip',
    'datashard',
    'callingchip',
    'infiltratorfragment',
    'travelpermit',
    'luminaflux',
    'stellarcoins',
    'plasmastabilizer',
    'plasmaticstabilizer',
    'plasmicequalizationplate',
    'plasmatequalizationplate',
    'cryonanocoolant',
    'neutronshard',
    'armorytoken',
    'megaarmorytoken',
    'optigradchips',
    'voyagersoathtoken',
    'horizonshard',
    'singularitydrivefragment',
    'chronoticgravitonlensfragment',
    'containmentnode',
    'ethershard',
  };

  /// Normalizes item string for robust matching (lowercase, alphanumeric only).
  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Classifies a single item by name into its corresponding [ItemCategory].
  static ItemCategory classify(String itemName) {
    final lower = itemName.toLowerCase().trim();
    final norm = _normalize(itemName);

    // 1. Trinity Trials & Particle Cannon Gear
    if (lower.contains('quantum prism') ||
        lower.contains('quantumprism') ||
        lower.contains('xyralith') ||
        lower.contains('trinity token') ||
        lower.contains('trinitytoken') ||
        lower.contains('os module') ||
        lower.contains('refractor') ||
        lower.contains('helios') ||
        lower.contains('nidhogg') ||
        lower.contains('indra') ||
        lower.contains('particle cannon')) {
      return ItemCategory.trinity;
    }

    // 2. Ammunition & Rockets
    // Check CC-A through CC-Z series
    if (RegExp(r'^cc[-_\s]?[a-z]$', caseSensitive: false).hasMatch(lower)) {
      return ItemCategory.ammo;
    }
    // Check known ammo map
    if (_knownAmmoNormalized.contains(norm)) {
      return ItemCategory.ammo;
    }
    // Ammo generic keywords
    if (lower.contains('laser') ||
        lower.contains('ammunition') ||
        lower.contains('ammo') ||
        lower.contains('rocket')) {
      return ItemCategory.ammo;
    }

    // 3. Resources & Minerals
    if (_knownResourcesNormalized.contains(norm)) {
      return ItemCategory.resource;
    }
    if (lower.contains('ore') ||
        lower.contains('mineral') ||
        lower.contains('fragment') ||
        lower.contains('alloy') ||
        lower.contains('chip') ||
        lower.contains('shard') ||
        lower.contains('voucher') ||
        lower.contains('key') ||
        lower.contains('token')) {
      return ItemCategory.resource;
    }

    // 4. Default fallback
    return ItemCategory.other;
  }

  /// Partitions a map of collected items by [ItemCategory], sorting each
  /// category's entries alphabetically.
  static Map<ItemCategory, Map<String, int>> categorizeItems(Map<String, int> items) {
    final result = <ItemCategory, Map<String, int>>{
      ItemCategory.trinity: {},
      ItemCategory.ammo: {},
      ItemCategory.resource: {},
      ItemCategory.other: {},
    };

    for (final entry in items.entries) {
      final category = classify(entry.key);
      result[category]![entry.key] = entry.value;
    }

    // Sort entries within each category alphabetically
    final sortedResult = <ItemCategory, Map<String, int>>{};
    for (final category in ItemCategory.values) {
      final map = result[category]!;
      if (map.isNotEmpty) {
        final sortedKeys = map.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        sortedResult[category] = {for (final k in sortedKeys) k: map[k]!};
      }
    }

    return sortedResult;
  }
}
