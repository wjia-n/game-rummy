import 'dart:math';
import 'package:flutter/material.dart';
import 'felt_themes.dart';

/// Card-room design system for Rummy: real felt, dark wood rails,
/// brass inlay, ivory card stock. No neon, no cyberpunk, no generic
/// Material look.
///
/// All widgets accept an optional [FeltThemeDef]; they default to the
/// Classic Casino theme so existing call sites keep working.
class Felt {
  // Classic palette (from DESIGN.md) — kept for compatibility.
  static const walnutDark = Color(0xFF3B2416);
  static const walnutMid = Color(0xFF5C3A21);
  static const walnutDeep = Color(0xFF241309);
  static const walnutLight = Color(0xFF7A5230);
  static const brass = Color(0xFFC9A227);
  static const brassLight = Color(0xFFE8CE7A);
  static const brassDark = Color(0xFF8A6D1A);
  static const ivory = Color(0xFFF5EFE0);
  static const ivoryDim = Color(0xFFD9CDAE);
  static const feltGreen = Color(0xFF1E4D3B);
  static const ruby = Color(0xFFA31621);
  static const sapphire = Color(0xFF1D4E9E);
  static const emerald = Color(0xFF1B7A4D);
  static const amber = Color(0xFFD99A2B);
  static const shadow = Color(0xFF1A0F08);

  static const displayFont = 'serif';

  static TextStyle display(double size,
          {Color? color, FeltThemeDef? theme}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? brassLight,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: shadow, offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, FeltThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.ivory ?? ivory,
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, FeltThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? brassLight,
        letterSpacing: 0.8,
      );

  static ThemeData theme([FeltThemeDef? t]) {
    t ??= FeltThemes.byId('casino');
    final darkText = t.id == 'ivory';
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.woodDark,
      colorScheme: ColorScheme(
        brightness: darkText ? Brightness.light : Brightness.dark,
        primary: t.accent,
        onPrimary: t.woodDeep,
        secondary: t.accentLight,
        onSecondary: t.woodDeep,
        surface: t.woodMid,
        onSurface: t.ivory,
        error: t.playerColors[0],
        onError: t.ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.woodMid),
    );
  }
}

/// Real card-table background: wooden rails at the edges, a woven felt
/// table in the middle, brass inlay line, warm vignette. Theme-aware.
class FeltBackdrop extends StatelessWidget {
  final Widget child;
  final FeltThemeDef? theme;
  const FeltBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.woodDeep, t.woodDark],
        ),
      ),
      child: CustomPaint(
        painter: _FeltTablePainter(t),
        child: child,
      ),
    );
  }
}

class _FeltTablePainter extends CustomPainter {
  final FeltThemeDef t;
  _FeltTablePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const rail = 26.0;
    // Felt inset panel.
    final feltRect = Rect.fromLTRB(rail, rail, size.width - rail, size.height - rail);
    canvas.drawRRect(
      RRect.fromRectAndRadius(feltRect, const Radius.circular(20)),
      Paint()..color = t.felt,
    );
    // Felt weave: fine diagonal hatching for fabric texture.
    final weave = Paint()
      ..color = t.woodDeep.withValues(alpha: 0.10)
      ..strokeWidth = 1.0;
    final path = Path();
    for (double d = -size.height; d < size.width; d += 7) {
      final p1 = Offset(d < rail ? rail : d, d < rail ? rail : rail);
      final p2 = Offset(d + size.height, rail + size.height - 2 * rail);
      path.moveTo(p1.dx.clamp(rail, size.width - rail), p1.dy);
      path.lineTo(p2.dx.clamp(rail, size.width - rail), p2.dy.clamp(rail, size.height - rail));
    }
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(feltRect, const Radius.circular(20)));
    canvas.drawPath(path, weave);
    canvas.restore();
    // Brass inlay around the felt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(feltRect, const Radius.circular(20)),
      Paint()
        ..color = t.accent.withValues(alpha: 0.9)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    // Vignette for depth.
    final vignette = RadialGradient(
      center: const Alignment(0, -0.15),
      radius: 1.2,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.35),
      ],
      stops: const [0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky wooden button with metal trim — looks physically pressable.
class FeltButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final FeltThemeDef? theme;

  const FeltButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.theme,
  });

  @override
  State<FeltButton> createState() => _FeltButtonState();
}

class _FeltButtonState extends State<FeltButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FeltThemes.byId('casino');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [t.woodMid, t.woodDark, t.woodDeep]
                : [
                    t.woodDeep.withValues(alpha: 0.7),
                    t.woodDeep.withValues(alpha: 0.5)
                  ],
          ),
          border: Border.all(color: t.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: t.accentLight.withValues(alpha: _pressed ? 0.05 : 0.22),
              offset: const Offset(0, -2),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Felt.display(widget.fontSize,
              theme: t,
              color: enabled
                  ? t.ivory
                  : t.ivory.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

/// An engraved metal plaque for titles.
class BrassPlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  final FeltThemeDef? theme;
  const BrassPlaque(
      {super.key, required this.title, this.subtitle, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.woodDeep, t.woodDark],
        ),
        border: Border.all(color: t.accent, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 6),
              blurRadius: 12),
          BoxShadow(
              color: t.accentLight.withValues(alpha: 0.7),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: Felt.display(30, theme: t),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Felt.body(14,
                    theme: t, color: t.ivory.withValues(alpha: 0.75)),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A metal lever toggle for settings.
class FeltToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final FeltThemeDef? theme;
  const FeltToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.accentDark : t.woodDeep,
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.accentDark],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A wooden-bead volume slider on a metal rail.
class BeadSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final FeltThemeDef? theme;
  const BeadSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.woodDeep,
        thumbShape: _BeadThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final FeltThemeDef t;
  const _BeadThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(
        center + const Offset(0, 2),
        12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// A chunky wooden dialog frame for announcements.
class WajihaDialog extends StatelessWidget {
  final String title;
  final String emoji;
  final List<Widget> children;
  final FeltThemeDef? theme;
  const WajihaDialog({
    super.key,
    required this.title,
    required this.emoji,
    required this.children,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDark, t.woodDeep],
          ),
          border: Border.all(color: t.accent, width: 3),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                offset: const Offset(0, 12),
                blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(title,
                style: Felt.display(26, theme: t), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Per-seat score chips; the active seat gets a brass glow ring.
class ScoreChips extends StatelessWidget {
  final List<String> names;
  final List<bool> isBot;
  final List<int> scores;
  final List<int> handCounts;
  final int activeIndex;
  final FeltThemeDef? theme;
  const ScoreChips({
    super.key,
    required this.names,
    required this.isBot,
    required this.scores,
    required this.handCounts,
    required this.activeIndex,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < names.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: t.woodDeep.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: i == activeIndex ? t.accentLight : t.accent.withValues(alpha: 0.35),
                width: i == activeIndex ? 2.5 : 1.2,
              ),
              boxShadow: i == activeIndex
                  ? [
                      BoxShadow(
                          color: t.accent.withValues(alpha: 0.55),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: t.playerColors[i]),
                ),
                const SizedBox(width: 6),
                Text(
                  '${isBot[i] ? "🤖 " : ""}${names[i]} · ${scores[i]}',
                  style: Felt.body(12, theme: t),
                ),
                if (handCounts.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('🂠${handCounts[i]}',
                      style: Felt.label(11,
                          theme: t, color: t.ivory.withValues(alpha: 0.7))),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Narration banner describing the current action (deal/draw/discard/meld).
class TurnBanner extends StatelessWidget {
  final String text;
  final FeltThemeDef? theme;
  const TurnBanner({super.key, required this.text, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(text),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: t.woodDeep.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.accent.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Text(
          text,
          style: Felt.body(13.5, theme: t, color: t.ivory),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// A physical playing card: ivory stock, beveled edge, drop shadow.
/// Renders a face-up card or a painted card back.
class PlayingCard extends StatelessWidget {
  final int rank; // 1=A .. 13=K
  final int suit; // 0=spade 1=heart 2=diamond 3=club
  final double width;
  final FeltThemeDef? theme;
  final int cardFaceStyle;
  final int cardBackStyle;
  final bool faceDown;
  final bool selected;
  final VoidCallback? onTap;

  const PlayingCard({
    super.key,
    this.rank = 1,
    this.suit = 0,
    this.width = 52,
    this.theme,
    this.cardFaceStyle = 0,
    this.cardBackStyle = 0,
    this.faceDown = false,
    this.selected = false,
    this.onTap,
  });

  static String rankLabel(int rank) => rank == 1
      ? 'A'
      : rank == 11
          ? 'J'
          : rank == 12
              ? 'Q'
              : rank == 13
                  ? 'K'
                  : '$rank';
  static String suitLabel(int suit) => '♠♥♦♣'[suit];
  static bool isRed(int suit) => suit == 1 || suit == 2;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    final h = width * 1.42;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -12 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.13),
        border: Border.all(
          color: selected ? t.accentLight : Colors.black38,
          width: selected ? 3 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: faceDown
          ? CustomPaint(painter: _CardBackPainter(cardBackStyle, t))
          : CustomPaint(painter: _CardFacePainter(rank, suit, cardFaceStyle, t)),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class _CardBackPainter extends CustomPainter {
  final int style;
  final FeltThemeDef t;
  _CardBackPainter(this.style, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.13));
    canvas.drawRRect(r, Paint()..color = t.ivory);
    final inset = r.deflate(size.width * 0.08);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(inset.outerRect, Radius.circular(size.width * 0.08)));
    final base = t.felt;
    canvas.drawRect(inset.outerRect, Paint()..color = base);
    final trim = t.trackLight;
    final dark = t.trackDark;
    final w = size.width;
    void diamond(Offset c, double s, Color col) {
      final p = Path()
        ..moveTo(c.dx, c.dy - s)
        ..lineTo(c.dx + s, c.dy)
        ..lineTo(c.dx, c.dy + s)
        ..lineTo(c.dx - s, c.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = col);
    }
    switch (style % 10) {
      case 1: // Brass Monogram: centered W monogram on felt.
        final tp = TextPainter(
          text: TextSpan(
              text: 'W',
              style: TextStyle(
                  color: trim, fontSize: w * 0.55, fontWeight: FontWeight.w900, fontFamily: 'serif')),
          textDirection: TextDirection.ltr,
        )
          ..layout();
        tp.paint(canvas, Offset((w - tp.width) / 2, (size.height - tp.height) / 2));
        break;
      case 2: // Emerald Lattice.
        final line = Paint()..color = trim.withValues(alpha: 0.8)..strokeWidth = 1.4;
        for (double d = 0; d < w + size.height; d += w * 0.22) {
          canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), line);
          canvas.drawLine(Offset(d + size.height, 0), Offset(d, size.height), line);
        }
        break;
      case 3: // Crimson Damask: dots in diamond grid.
        for (var iy = 0; iy < 7; iy++) {
          for (var ix = 0; ix < 4; ix++) {
            final cx = inset.left + inset.width * (ix + 0.5) / 4 + (iy.isEven ? 0 : inset.width / 8);
            final cy = inset.top + inset.height * (iy + 0.5) / 7;
            canvas.drawCircle(Offset(cx, cy), w * 0.055, Paint()..color = (ix + iy).isEven ? trim : dark);
          }
        }
        break;
      case 4: // Sapphire Scroll: concentric diamonds.
        for (var k = 0; k < 4; k++) {
          final c = Offset(w / 2, size.height / 2);
          diamond(c, w * (0.42 - k * 0.09), k.isEven ? trim : dark);
        }
        break;
      case 5: // Ivory Filigree: corner flourishes + center diamond.
        for (final sx in [inset.left, inset.right]) {
          for (final sy in [inset.top, inset.bottom]) {
            canvas.drawCircle(Offset(sx, sy), w * 0.09, Paint()..color = trim);
          }
        }
        diamond(Offset(w / 2, size.height / 2), w * 0.3, trim);
        diamond(Offset(w / 2, size.height / 2), w * 0.18, dark);
        break;
      case 6: // Noir Diamond: black base with ivory diamonds.
        canvas.drawRect(inset.outerRect, Paint()..color = const Color(0xFF141414));
        for (var iy = 0; iy < 6; iy++) {
          for (var ix = 0; ix < 4; ix++) {
            diamond(
              Offset(inset.left + inset.width * (ix + 0.5) / 4,
                  inset.top + inset.height * (iy + 0.5) / 6),
              w * 0.075,
              (ix + iy).isEven ? trim : dark,
            );
          }
        }
        break;
      case 7: // Harbor Rope: rope border.
        final rope = Paint()
          ..color = trim
          ..strokeWidth = w * 0.05
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k < 3; k++) {
          final rr = inset.deflate(k * w * 0.09);
          canvas.drawRRect(RRect.fromRectAndRadius(rr.outerRect, Radius.circular(size.width * 0.06)), rope);
        }
        break;
      case 8: // Autumn Vine: vertical vines with leaves.
        final vine = Paint()..color = dark..strokeWidth = 1.6;
        for (var ix = 0; ix < 3; ix++) {
          final x = inset.left + inset.width * (ix + 0.5) / 3;
          canvas.drawLine(Offset(x, inset.top), Offset(x, inset.bottom), vine);
          for (var iy = 0; iy < 6; iy++) {
            final y = inset.top + inset.height * (iy + 0.5) / 6;
            canvas.drawCircle(Offset(x + (iy.isEven ? 4 : -4), y), w * 0.045,
                Paint()..color = iy.isEven ? trim : dark);
          }
        }
        break;
      case 9: // Pearl Deco: fan of arcs.
        for (var k = 0; k < 5; k++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(w / 2, size.height * 0.95), radius: w * (0.3 + k * 0.14)),
            -2.4,
            1.65,
            false,
            Paint()
              ..color = k.isEven ? trim : dark
              ..strokeWidth = 1.6
              ..style = PaintingStyle.stroke,
          );
        }
        break;
      default: // Classic Felt: cross-hatch weave + center medallion.
        final hatch = Paint()..color = trim.withValues(alpha: 0.55)..strokeWidth = 1.2;
        for (double d = inset.left; d < inset.right + inset.height; d += w * 0.18) {
          canvas.drawLine(Offset(d, inset.top), Offset(d + inset.height, inset.bottom), hatch);
        }
        diamond(Offset(w / 2, size.height / 2), w * 0.28, trim);
        diamond(Offset(w / 2, size.height / 2), w * 0.18, dark);
    }
    canvas.restore();
    canvas.drawRRect(r, Paint()..color = t.ivory.withValues(alpha: 0.06));
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter old) =>
      old.style != style || old.t != t;
}

class _CardFacePainter extends CustomPainter {
  final int rank;
  final int suit;
  final int style;
  final FeltThemeDef t;
  _CardFacePainter(this.rank, this.suit, this.style, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.13));
    canvas.drawRRect(r, Paint()..color = t.ivory);
    // Subtle paper texture.
    canvas.drawRRect(r, Paint()..color = t.woodDeep.withValues(alpha: 0.04));
    final w = size.width;
    final h = size.height;
    final red = PlayingCard.isRed(suit);
    final ink = red ? const Color(0xFF9E1B25) : const Color(0xFF1F2430);
    final pad = w * 0.12;

    void cornerLabel(bool upsideDown) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${PlayingCard.rankLabel(rank)}\n${PlayingCard.suitLabel(suit)}',
          style: TextStyle(
            color: ink,
            fontSize: w * 0.26,
            fontWeight: FontWeight.w900,
            height: 1.05,
            fontFamily: 'serif',
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )
        ..layout();
      canvas.save();
      if (upsideDown) {
        canvas.translate(w - pad - tp.width, h - pad - tp.height);
        canvas.rotate(3.14159);
        canvas.translate(-pad, -pad);
      } else {
        canvas.translate(pad, pad);
      }
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }

    cornerLabel(false);
    cornerLabel(true);

    // Center pip motif varies by style.
    final c = Offset(w / 2, h / 2);
    switch (style % 8) {
      case 1: // Vintage Casino: large pip + ring.
        canvas.drawCircle(c, w * 0.26, Paint()..color = ink.withValues(alpha: 0.12));
        canvas.drawCircle(c, w * 0.26, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 1.6);
        _pip(canvas, c, w * 0.34, ink);
        break;
      case 2: // Bold Club: heavy pip on brass disc.
        canvas.drawCircle(c, w * 0.3, Paint()..color = t.accent.withValues(alpha: 0.28));
        _pip(canvas, c, w * 0.36, ink);
        break;
      case 3: // Art Deco: pip inside diamond frame.
        final d = w * 0.3;
        final p = Path()
          ..moveTo(c.dx, c.dy - d)
          ..lineTo(c.dx + d, c.dy)
          ..lineTo(c.dx, c.dy + d)
          ..lineTo(c.dx - d, c.dy)
          ..close();
        canvas.drawPath(p, Paint()..color = ink.withValues(alpha: 0.1));
        canvas.drawPath(p, Paint()..color = t.accent..style = PaintingStyle.stroke..strokeWidth = 1.8);
        _pip(canvas, c, w * 0.28, ink);
        break;
      case 4: // Botanical: pip surrounded by dots.
        for (var k = 0; k < 8; k++) {
          final a = k * 3.14159 / 4;
          canvas.drawCircle(Offset(c.dx + cos(a) * w * 0.3, c.dy + sin(a) * w * 0.3), w * 0.045,
              Paint()..color = t.accent);
        }
        _pip(canvas, c, w * 0.3, ink);
        break;
      case 5: // Heritage: double ring + pip.
        canvas.drawCircle(c, w * 0.32, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 1.2);
        canvas.drawCircle(c, w * 0.27, Paint()..color = t.accent..style = PaintingStyle.stroke..strokeWidth = 1.2);
        _pip(canvas, c, w * 0.3, ink);
        break;
      case 6: // Minimal Line: thin pip outline only.
        _pip(canvas, c, w * 0.32, ink, outline: true);
        break;
      case 7: // Ivory Script: large serif rank letter.
        final tp = TextPainter(
          text: TextSpan(
            text: PlayingCard.rankLabel(rank),
            style: TextStyle(
                color: ink, fontSize: w * 0.62, fontWeight: FontWeight.w700, fontFamily: 'serif'),
          ),
          textDirection: TextDirection.ltr,
        )
          ..layout();
        tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
        break;
      default: // Standard Court: pip + suit small repeat.
        _pip(canvas, c, w * 0.32, ink);
        _pip(canvas, Offset(c.dx, c.dy + w * 0.4), w * 0.12, ink.withValues(alpha: 0.5));
        _pip(canvas, Offset(c.dx, c.dy - w * 0.4), w * 0.12, ink.withValues(alpha: 0.5));
    }
  }

  void _pip(Canvas canvas, Offset c, double s, Color ink, {bool outline = false}) {
    final label = PlayingCard.suitLabel(suit);
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: ink, fontSize: s)),
      textDirection: TextDirection.ltr,
    )
      ..layout();
    if (outline) {
      // Outline look: thin ring around the pip.
      canvas.drawCircle(
        c,
        s * 0.42,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CardFacePainter old) =>
      old.rank != rank || old.suit != suit || old.style != style || old.t != t;
}

/// Small helper: a labeled settings row.
class SettingRow extends StatelessWidget {
  final String label;
  final Widget control;
  final FeltThemeDef? theme;
  const SettingRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FeltThemes.byId('casino');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: t.woodDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Felt.body(16, theme: t))),
          control,
        ],
      ),
    );
  }
}
