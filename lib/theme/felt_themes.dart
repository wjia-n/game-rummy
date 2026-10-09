import 'package:flutter/material.dart';

/// Theme, card-back and card-face catalog for Rummy.
///
/// Every theme stays inside the classic card-room material world: real
/// felt of many colors, dark wood table rails, brass inlay, ivory card
/// stock. Variety comes from different felts, rail woods, inlay metals
/// and seat jewel tones. No neon, no gradients-for-looks.
class FeltThemeDef {
  final String id;
  final String name;
  final Color woodDark; // table rail / frame
  final Color woodMid;
  final Color woodDeep;
  final Color accent; // brass / silver / copper inlay
  final Color accentLight;
  final Color accentDark;
  final Color ivory; // card stock
  final Color felt; // table felt
  final Color trackLight; // card trim / back pattern light
  final Color trackDark; // card trim / back pattern dark
  final List<Color> playerColors; // 4 seat colors
  final List<String> playerColorNames;

  const FeltThemeDef({
    required this.id,
    required this.name,
    required this.woodDark,
    required this.woodMid,
    required this.woodDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.felt,
    required this.trackLight,
    required this.trackDark,
    required this.playerColors,
    required this.playerColorNames,
  });
}

FeltThemeDef _t({
  required String id,
  required String name,
  required int rail,
  required int railMid,
  required int railDeep,
  required int inlay,
  required int inlayLight,
  required int inlayDark,
  required int ivory,
  required int felt,
  required int trimLight,
  required int trimDark,
  required List<int> seats,
  required List<String> seatNames,
}) =>
    FeltThemeDef(
      id: id,
      name: name,
      woodDark: Color(rail),
      woodMid: Color(railMid),
      woodDeep: Color(railDeep),
      accent: Color(inlay),
      accentLight: Color(inlayLight),
      accentDark: Color(inlayDark),
      ivory: Color(ivory),
      felt: Color(felt),
      trackLight: Color(trimLight),
      trackDark: Color(trimDark),
      playerColors: seats.map(Color.new).toList(),
      playerColorNames: seatNames,
    );

class FeltThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'casino',
    'emerald',
    'oxblood',
    'midnight',
  ];

  static final List<FeltThemeDef> all = [
    _t(
      id: 'casino',
      name: 'Classic Casino',
      rail: 0xFF3B2416,
      railMid: 0xFF5C3A21,
      railDeep: 0xFF241309,
      inlay: 0xFFC9A227,
      inlayLight: 0xFFE8CE7A,
      inlayDark: 0xFF8A6D1A,
      ivory: 0xFFF7F1E3,
      felt: 0xFF1E5C40,
      trimLight: 0xFFEFE3C8,
      trimDark: 0xFFE0CFA6,
      seats: [0xFFA31621, 0xFF1D4E9E, 0xFF1B7A4D, 0xFFD99A2B],
      seatNames: ['Ruby', 'Sapphire', 'Emerald', 'Amber'],
    ),
    _t(
      id: 'emerald',
      name: 'Emerald Club',
      rail: 0xFF2E3B22,
      railMid: 0xFF4A5A34,
      railDeep: 0xFF1A2312,
      inlay: 0xFFD4AF37,
      inlayLight: 0xFFF3DC8E,
      inlayDark: 0xFF96702A,
      ivory: 0xFFF5EFE0,
      felt: 0xFF2E6B4F,
      trimLight: 0xFFEAF0D8,
      trimDark: 0xFFD3DDB8,
      seats: [0xFFC0392B, 0xFF7D3C98, 0xFF1E8449, 0xFFB7950B],
      seatNames: ['Garnet', 'Amethyst', 'Jade', 'Topaz'],
    ),
    _t(
      id: 'oxblood',
      name: 'Oxblood Library',
      rail: 0xFF3A1D18,
      railMid: 0xFF5A2E24,
      railDeep: 0xFF22100C,
      inlay: 0xFFC9A227,
      inlayLight: 0xFFE8CE7A,
      inlayDark: 0xFF8A6D1A,
      ivory: 0xFFF8F1E2,
      felt: 0xFF6E2A2A,
      trimLight: 0xFFF2E6CC,
      trimDark: 0xFFE6D2A6,
      seats: [0xFFD64545, 0xFFE0A83C, 0xFF4A90D9, 0xFF3FB97F],
      seatNames: ['Ember', 'Candle', 'Moonstone', 'Fern'],
    ),
    _t(
      id: 'midnight',
      name: 'Midnight Rail',
      rail: 0xFF1C2438,
      railMid: 0xFF2C3A55,
      railDeep: 0xFF101624,
      inlay: 0xFFC0C6D4,
      inlayLight: 0xFFE8ECF5,
      inlayDark: 0xFF7E8698,
      ivory: 0xFFF2EEE4,
      felt: 0xFF22375E,
      trimLight: 0xFFE9E4D2,
      trimDark: 0xFFD5CDAE,
      seats: [0xFFD64545, 0xFF4A90D9, 0xFF3FB97F, 0xFFE0A83C],
      seatNames: ['Comet', 'Marina', 'Fern', 'Beacon'],
    ),
    _t(
      id: 'rosewood',
      name: 'Rosewood Parlor',
      rail: 0xFF4A1F14,
      railMid: 0xFF6E2F1C,
      railDeep: 0xFF2B1009,
      inlay: 0xFFD4AF37,
      inlayLight: 0xFFF3DC8E,
      inlayDark: 0xFF96702A,
      ivory: 0xFFF8F1E2,
      felt: 0xFF3D1F2E,
      trimLight: 0xFFF2E6CC,
      trimDark: 0xFFE6D2A6,
      seats: [0xFFC0392B, 0xFF7D3C98, 0xFF1E8449, 0xFFB7950B],
      seatNames: ['Wine', 'Violet', 'Moss', 'Honey'],
    ),
    _t(
      id: 'chartreuse',
      name: 'Chartreuse Clubhouse',
      rail: 0xFF33390F,
      railMid: 0xFF4C5418,
      railDeep: 0xFF1C1F08,
      inlay: 0xFFC9A227,
      inlayLight: 0xFFE8CE7A,
      inlayDark: 0xFF8A6D1A,
      ivory: 0xFFF9F4E4,
      felt: 0xFF6B7A2B,
      trimLight: 0xFFF4ECD2,
      trimDark: 0xFFE2D4A8,
      seats: [0xFF8B0000, 0xFF2F4F4F, 0xFFB8860B, 0xFF556B2F],
      seatNames: ['Brick', 'Slate', 'Ochre', 'Olive'],
    ),
    _t(
      id: 'cobalt',
      name: 'Cobalt Smoke Room',
      rail: 0xFF20242E,
      railMid: 0xFF333945,
      railDeep: 0xFF12141B,
      inlay: 0xFFB8BDC9,
      inlayLight: 0xFFDEE3EC,
      inlayDark: 0xFF757C8B,
      ivory: 0xFFF3EEE1,
      felt: 0xFF1F3A5F,
      trimLight: 0xFFEDE8D4,
      trimDark: 0xFFDBD2B4,
      seats: [0xFFE63946, 0xFF457B9D, 0xFF2A9D8F, 0xFFE9C46A],
      seatNames: ['Chili', 'Steel', 'Teal', 'Sand'],
    ),
    _t(
      id: 'burgundy',
      name: 'Burgundy Study',
      rail: 0xFF2E1410,
      railMid: 0xFF4A211A,
      railDeep: 0xFF1A0C08,
      inlay: 0xFFC0C6D4,
      inlayLight: 0xFFE8ECF5,
      inlayDark: 0xFF7E8698,
      ivory: 0xFFF5EDE0,
      felt: 0xFF5C2433,
      trimLight: 0xFFF0E4CC,
      trimDark: 0xFFE2CFA4,
      seats: [0xFFD4A017, 0xFF8E4585, 0xFF2E8B57, 0xFFCD5C5C],
      seatNames: ['Gold', 'Plum', 'Sea', 'Rose'],
    ),
    _t(
      id: 'hunter',
      name: 'Hunter Lodge',
      rail: 0xFF2F2418,
      railMid: 0xFF4C3A24,
      railDeep: 0xFF1C1409,
      inlay: 0xFFB87333,
      inlayLight: 0xFFDDA86A,
      inlayDark: 0xFF7D4E22,
      ivory: 0xFFF6F0DF,
      felt: 0xFF2F5233,
      trimLight: 0xFFEDE3C6,
      trimDark: 0xFFDCCB9C,
      seats: [0xFFA31621, 0xFF1D4E9E, 0xFFD99A2B, 0xFF1B7A4D],
      seatNames: ['Copper', 'Denim', 'Wheat', 'Pine'],
    ),
    _t(
      id: 'porcelain',
      name: 'Porcelain Tea Room',
      rail: 0xFF4E3B2A,
      railMid: 0xFF6B5240,
      railDeep: 0xFF33261A,
      inlay: 0xFFC9A227,
      inlayLight: 0xFFE8CE7A,
      inlayDark: 0xFF8A6D1A,
      ivory: 0xFFFBF7EC,
      felt: 0xFF7A8B99,
      trimLight: 0xFFF4EDD8,
      trimDark: 0xFFE4D6B2,
      seats: [0xFF9B1B30, 0xFF1F4E79, 0xFF2E6B46, 0xFFB98A2F],
      seatNames: ['Cranberry', 'Navy', 'Pine', 'Brass'],
    ),
    _t(
      id: 'mahogany',
      name: 'Royal Mahogany',
      rail: 0xFF4A1F14,
      railMid: 0xFF6E2F1C,
      railDeep: 0xFF2B1009,
      inlay: 0xFFD4AF37,
      inlayLight: 0xFFF3DC8E,
      inlayDark: 0xFF96702A,
      ivory: 0xFFF8F1E2,
      felt: 0xFF1E4D3B,
      trimLight: 0xFFF2E6CC,
      trimDark: 0xFFE6D2A6,
      seats: [0xFFC0392B, 0xFF7D3C98, 0xFF1E8449, 0xFFB7950B],
      seatNames: ['Garnet', 'Amethyst', 'Jade', 'Topaz'],
    ),
    _t(
      id: 'smoke',
      name: 'Smoked Walnut',
      rail: 0xFF2B231B,
      railMid: 0xFF423629,
      railDeep: 0xFF17120D,
      inlay: 0xFFB08D57,
      inlayLight: 0xFFD9BE8C,
      inlayDark: 0xFF77603A,
      ivory: 0xFFF4EEDF,
      felt: 0xFF3E5A45,
      trimLight: 0xFFEFE6CB,
      trimDark: 0xFFE0D0A2,
      seats: [0xFFB5451B, 0xFF33658A, 0xFF86BBD8, 0xFFD8B656],
      seatNames: ['Rust', 'Harbor', 'Glacier', 'Harvest'],
    ),
    _t(
      id: 'vermilion',
      name: 'Vermilion Den',
      rail: 0xFF351711,
      railMid: 0xFF52241A,
      railDeep: 0xFF200D08,
      inlay: 0xFFD4AF37,
      inlayLight: 0xFFF3DC8E,
      inlayDark: 0xFF96702A,
      ivory: 0xFFF7F0E1,
      felt: 0xFF8A2E1F,
      trimLight: 0xFFF3E7CC,
      trimDark: 0xFFE7D1A4,
      seats: [0xFFE8B04B, 0xFF2E86AB, 0xFFF24236, 0xFF1B7A4D],
      seatNames: ['Marigold', 'River', 'Flame', 'Mint'],
    ),
    _t(
      id: 'jade',
      name: 'Jade Emperor',
      rail: 0xFF1F2A1E,
      railMid: 0xFF31412F,
      railDeep: 0xFF121A11,
      inlay: 0xFFD4AF37,
      inlayLight: 0xFFF3DC8E,
      inlayDark: 0xFF96702A,
      ivory: 0xFFF6F2E4,
      felt: 0xFF2F6B5E,
      trimLight: 0xFFECE6CC,
      trimDark: 0xFFDCD0A6,
      seats: [0xFFC1272D, 0xFFE9C46A, 0xFF457B9D, 0xFF8AB17D],
      seatNames: ['Cinnabar', 'Silk', 'Ink', 'Celadon'],
    ),
  ];

  static FeltThemeDef byId(String id, {FeltThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) => !freeThemeIds.contains(id);
}

/// Card-back styles. 10 physical patterns painted on real card stock.
/// First 4 are FREE; the rest are PRO.
class CardBackStyles {
  static const List<String> names = [
    'Classic Felt',
    'Brass Monogram',
    'Emerald Lattice',
    'Crimson Damask',
    'Sapphire Scroll',
    'Ivory Filigree',
    'Noir Diamond',
    'Harbor Rope',
    'Autumn Vine',
    'Pearl Deco',
  ];

  static bool isPro(int index) => index >= 4;
}

/// Card-face styles. 8 court-card renderings. First 3 are FREE.
class CardFaceStyles {
  static const List<String> names = [
    'Standard Court',
    'Vintage Casino',
    'Bold Club',
    'Art Deco',
    'Botanical',
    'Heritage',
    'Minimal Line',
    'Ivory Script',
  ];

  static bool isPro(int index) => index >= 3;
}
