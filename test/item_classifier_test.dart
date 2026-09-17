import 'package:astra_lawnchair/astra_lawnchair.dart';
import 'package:test/test.dart';

void main() {
  group('ItemClassifier', () {
    test('classifies Trinity Trials and Particle Cannon gear', () {
      expect(ItemClassifier.classify('Quantum Prism'), ItemCategory.trinity);
      expect(ItemClassifier.classify('Quantum Prisms'), ItemCategory.trinity);
      expect(ItemClassifier.classify('Xyralith'), ItemCategory.trinity);
      expect(ItemClassifier.classify('Trinity Token'), ItemCategory.trinity);
      expect(ItemClassifier.classify('Common Helios'), ItemCategory.trinity);
      expect(ItemClassifier.classify('Rare Nidhogg'), ItemCategory.trinity);
      expect(ItemClassifier.classify('Ultimate Indra'), ItemCategory.trinity);
      expect(ItemClassifier.classify('OS Module'), ItemCategory.trinity);
      expect(ItemClassifier.classify('Particle Cannon Refractor'), ItemCategory.trinity);
    });

    test('classifies Ammunition and Rockets', () {
      // Lasers
      expect(ItemClassifier.classify('UCB-100'), ItemCategory.ammo);
      expect(ItemClassifier.classify('RSB-75'), ItemCategory.ammo);
      expect(ItemClassifier.classify('MCB-25'), ItemCategory.ammo);
      expect(ItemClassifier.classify('SAB-50'), ItemCategory.ammo);
      expect(ItemClassifier.classify('A-BL'), ItemCategory.ammo);
      expect(ItemClassifier.classify('CC-D'), ItemCategory.ammo);
      expect(ItemClassifier.classify('EMAA-20'), ItemCategory.ammo);
      expect(ItemClassifier.classify('IDB-125'), ItemCategory.ammo);

      // Rockets
      expect(ItemClassifier.classify('PLT-2021'), ItemCategory.ammo);
      expect(ItemClassifier.classify('PLT-3030'), ItemCategory.ammo);
      expect(ItemClassifier.classify('R-310'), ItemCategory.ammo);
      expect(ItemClassifier.classify('DCR-250'), ItemCategory.ammo);
      expect(ItemClassifier.classify('R-IC3'), ItemCategory.ammo);
      expect(ItemClassifier.classify('HSTRM-01'), ItemCategory.ammo);
      expect(ItemClassifier.classify('UBR-100'), ItemCategory.ammo);
    });

    test('classifies Resources, Ores, and Crafting Materials', () {
      expect(ItemClassifier.classify('Promerium'), ItemCategory.resource);
      expect(ItemClassifier.classify('Seprom'), ItemCategory.resource);
      expect(ItemClassifier.classify('Palladium'), ItemCategory.resource);
      expect(ItemClassifier.classify('Mucosum'), ItemCategory.resource);
      expect(ItemClassifier.classify('Scrap'), ItemCategory.resource);
      expect(ItemClassifier.classify('Rinusk'), ItemCategory.resource);
      expect(ItemClassifier.classify('Diametrion'), ItemCategory.resource);
      expect(ItemClassifier.classify('BlackLight Trace'), ItemCategory.resource);
      expect(ItemClassifier.classify('Log Disk'), ItemCategory.resource);
      expect(ItemClassifier.classify('Green Booty Key'), ItemCategory.resource);
      expect(ItemClassifier.classify('Repair Voucher'), ItemCategory.resource);
    });

    test('categorizes and sorts collected item map into categorized buckets', () {
      final input = {
        'Seprom': 500,
        'UCB-100': 10000,
        'Quantum Prism': 15,
        'Alien Mystery Cube': 1,
        'PLT-2021': 50,
        'Promerium': 200,
        'Common Helios': 1,
      };

      final categorized = ItemClassifier.categorizeItems(input);

      // Trinity category
      expect(categorized[ItemCategory.trinity]?.keys.toList(), [
        'Common Helios',
        'Quantum Prism',
      ]);

      // Ammo category
      expect(categorized[ItemCategory.ammo]?.keys.toList(), [
        'PLT-2021',
        'UCB-100',
      ]);

      // Resource category
      expect(categorized[ItemCategory.resource]?.keys.toList(), [
        'Promerium',
        'Seprom',
      ]);

      // Other category
      expect(categorized[ItemCategory.other]?.keys.toList(), [
        'Alien Mystery Cube',
      ]);
    });
  });
}
