import 'package:flutter/material.dart';

// =============================================================================
// OMIGO APP — MINTLIFY DESIGN SYSTEM TOKENS
// Reference: mintlify.com design system brief
// =============================================================================

abstract class AppColors {
  // ── Brand & Accent ──────────────────────────────────────────────────────────
  static const brandGreen     = Color(0xFF099C7E); // Emerald/Teal brand color
  static const brandGreenDeep = Color(0xFF067D65); // Pressed/active emerald
  static const brandGreenSoft = Color(0xFFE6F5F2); // Emerald surface tint

  // ── Text — Light Mode ───────────────────────────────────────────────────────
  static const ink      = Color(0xFF111827); // Primary headlines & CTA text
  static const charcoal = Color(0xFF1F2937); // Body text
  static const slate    = Color(0xFF374151); // Secondary text
  static const steel    = Color(0xFF6B7280); // Tertiary / muted
  static const stone    = Color(0xFF9CA3AF); // Captions / disabled labels
  static const muted    = Color(0xFFD1D5DB); // De-emphasized / disabled

  // ── Surface — Light Mode ────────────────────────────────────────────────────
  static const canvas      = Color(0xFFFFFFFF); // Primary page & card bg
  static const surface     = Color(0xFFF9FAFB); // Section bg / sidebar active
  static const surfaceSoft = Color(0xFFF3F4F6); // Quieter section bg
  static const hairline    = Color(0xFFE5E7EB); // 1px borders / dividers
  static const hairlineSoft= Color(0xFFF3F4F6); // Quieter table-row dividers

  // ── Surface — Dark Mode ─────────────────────────────────────────────────────
  static const canvasDark   = Color(0xFF090E17); // Dark canvas
  static const surfaceDark  = Color(0xFF0F1A2B); // Dark card bg
  static const surfaceCode  = Color(0xFF141E30); // Dark code block
  static const hairlineDark = Color(0xFF1F2937); // Dark 1px border

  // ── Text — Dark Mode ────────────────────────────────────────────────────────
  static const onDark      = Color(0xFFFFFFFF); // White on dark surfaces
  static const onDarkMuted = Color(0xFFFFFFFF); // Muted white (use withOpacity)

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const brandError       = Color(0xFFEF4444); // Required/error red
  static const testimonialOrange= Color(0xFFF97316); // Orange callout

  // ── Dynamic helpers ─────────────────────────────────────────────────────────
  /// Primary page background — light/dark adaptive
  static Color canvas_(bool isDark) => isDark ? canvasDark : canvas;
  /// Card background — light/dark adaptive
  static Color card_(bool isDark) => isDark ? surfaceDark : canvas;
  /// Section background — light/dark adaptive
  static Color surface_(bool isDark) => isDark ? surfaceDark : surface;
  /// Hairline border color — light/dark adaptive
  static Color hairline_(bool isDark) => isDark ? hairlineDark : hairline;
  /// Primary text — light/dark adaptive
  static Color ink_(bool isDark) => isDark ? onDark : ink;
  /// Secondary text — light/dark adaptive
  static Color steel_(bool isDark) => isDark ? const Color(0xFF9CA3AF) : steel;
  /// Muted text — light/dark adaptive
  static Color stone_(bool isDark) => isDark ? const Color(0xFF6B7280) : stone;
}

// =============================================================================
// RADIUS SCALE
// =============================================================================
abstract class AppRadius {
  static const double xs   = 4;
  static const double sm   = 6;
  static const double md   = 8;
  static const double lg   = 12;
  static const double xl   = 16;
  static const double xxl  = 24;
  static const double full = 999;

  static BorderRadius get _xs   => BorderRadius.circular(xs);
  static BorderRadius get _sm   => BorderRadius.circular(sm);
  static BorderRadius get _md   => BorderRadius.circular(md);
  static BorderRadius get _lg   => BorderRadius.circular(lg);
  static BorderRadius get _xl   => BorderRadius.circular(xl);
  static BorderRadius get _xxl  => BorderRadius.circular(xxl);
  static BorderRadius get _full => BorderRadius.circular(full);

  static BorderRadius xs_   = _xs;
  static BorderRadius sm_   = _sm;
  static BorderRadius md_   = _md;
  static BorderRadius lg_   = _lg;
  static BorderRadius xl_   = _xl;
  static BorderRadius xxl_  = _xxl;
  static BorderRadius full_ = _full;
}

// =============================================================================
// SPACING SCALE (4px base)
// =============================================================================
abstract class AppSpacing {
  static const double xxs       = 4;
  static const double xs        = 8;
  static const double sm        = 12;
  static const double md        = 16;
  static const double lg        = 20;
  static const double xl        = 24;
  static const double xxl       = 32;
  static const double xxxl      = 40;
  static const double sectionSm = 48;
  static const double section   = 64;
  static const double sectionLg = 96;
  static const double hero      = 120;
}

// =============================================================================
// TYPOGRAPHY PRESETS
// Inter (primary) + Geist Mono (code)
// =============================================================================
abstract class AppText {
  // ── Marketing Display ───────────────────────────────────────────────────────
  static const heroDisplay = TextStyle(
    fontFamily: 'Inter', fontSize: 72, fontWeight: FontWeight.w600,
    height: 1.05, letterSpacing: -2,
  );
  static const displayLg = TextStyle(
    fontFamily: 'Inter', fontSize: 56, fontWeight: FontWeight.w600,
    height: 1.10, letterSpacing: -1.5,
  );

  // ── Headings ────────────────────────────────────────────────────────────────
  static const heading1 = TextStyle(
    fontFamily: 'Inter', fontSize: 48, fontWeight: FontWeight.w600,
    height: 1.10, letterSpacing: -1,
  );
  static const heading2 = TextStyle(
    fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w600,
    height: 1.20, letterSpacing: -0.5,
  );
  static const heading3 = TextStyle(
    fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w600,
    height: 1.25, letterSpacing: 0,
  );
  static const heading4 = TextStyle(
    fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w600,
    height: 1.30, letterSpacing: 0,
  );
  static const heading5 = TextStyle(
    fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600,
    height: 1.40, letterSpacing: 0,
  );

  // ── Body ────────────────────────────────────────────────────────────────────
  static const subtitle = TextStyle(
    fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w400,
    height: 1.50, letterSpacing: 0,
  );
  static const bodyMd = TextStyle(
    fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400,
    height: 1.50, letterSpacing: 0,
  );
  static const bodyMdMedium = TextStyle(
    fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500,
    height: 1.50, letterSpacing: 0,
  );
  static const bodySm = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400,
    height: 1.50, letterSpacing: 0,
  );
  static const bodySmMedium = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    height: 1.50, letterSpacing: 0,
  );

  // ── Caption & Micro ──────────────────────────────────────────────────────────
  static const caption = TextStyle(
    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.40, letterSpacing: 0,
  );
  static const captionBold = TextStyle(
    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600,
    height: 1.40, letterSpacing: 0,
  );
  static const micro = TextStyle(
    fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500,
    height: 1.40, letterSpacing: 0,
  );
  /// For sidebar section headers, "REQUIRED" labels — ALL CAPS
  static const microUppercase = TextStyle(
    fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600,
    height: 1.40, letterSpacing: 0.5,
  );

  // ── Buttons ──────────────────────────────────────────────────────────────────
  static const buttonMd = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    height: 1.30, letterSpacing: 0,
  );

  // ── Code (Geist Mono) ────────────────────────────────────────────────────────
  static const codeMd = TextStyle(
    fontFamily: 'Geist Mono', fontSize: 14, fontWeight: FontWeight.w400,
    height: 1.50, letterSpacing: 0,
  );
  static const codeSm = TextStyle(
    fontFamily: 'Geist Mono', fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.40, letterSpacing: 0,
  );
  static const codeInline = TextStyle(
    fontFamily: 'Geist Mono', fontSize: 13, fontWeight: FontWeight.w500,
    height: 1.30, letterSpacing: 0,
  );
}

// =============================================================================
// ELEVATION / SHADOW SCALE
// =============================================================================
abstract class AppShadow {
  /// Level 0 — flat (border only, no shadow)
  static const List<BoxShadow> level0 = [];

  /// Level 1 — subtle hover lift
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Level 2 — standard card
  static const List<BoxShadow> level2 = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Level 3 — hero product mockup deep shadow
  static const List<BoxShadow> level3 = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 48, spreadRadius: -8, offset: Offset(0, 24)),
  ];

  /// Level 4 — brand-tinted featured pricing glow
  static const List<BoxShadow> level4 = [
    BoxShadow(color: Color(0x1400D4A4), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

// =============================================================================
// SHARED WIDGET HELPERS
// =============================================================================

/// Standard section/card horizontal padding
const kPageHPad = EdgeInsets.symmetric(horizontal: AppSpacing.xl);

/// Build a Mintlify `card-base` decoration
BoxDecoration cardDecoration(bool isDark, {
  double radius = AppRadius.lg,
  bool featured = false,
  List<BoxShadow>? shadow,
}) {
  return BoxDecoration(
    color: AppColors.card_(isDark),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: featured ? AppColors.brandGreen : AppColors.hairline_(isDark),
      width: featured ? 2 : 1,
    ),
    boxShadow: shadow ??
        (featured
            ? AppShadow.level4
            : (isDark
                ? AppShadow.level0
                : const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ])),
  );
}

/// Build a `micro-uppercase` section label (like "HÀNH TRÌNH", "THANH TOÁN")
Widget sectionLabel(String text, bool isDark) {
  return Text(
    text.toUpperCase(),
    style: AppText.microUppercase.copyWith(color: AppColors.steel_(isDark)),
  );
}

/// Status → color mapping (shared across history + tracking + details screens)
Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'new':
    case 'pending':    return const Color(0xFFF59E0B); // amber
    case 'confirmed':  return const Color(0xFF3B82F6); // blue
    case 'assigned':   return AppColors.brandGreen;
    case 'on_trip':    return const Color(0xFF8B5CF6); // purple
    case 'completed':  return const Color(0xFF10B981); // emerald
    case 'cancelled':  return AppColors.brandError;
    default:           return AppColors.steel;
  }
}

String statusLabel(String status, String lang) {
  final vi = lang == 'vi';
  switch (status.toLowerCase()) {
    case 'new':
    case 'pending':   return vi ? 'Đang tìm tài xế' : 'Finding driver';
    case 'confirmed': return vi ? 'Đã xác nhận' : 'Confirmed';
    case 'assigned':  return vi ? 'Tài xế đang đến' : 'Driver on way';
    case 'on_trip':   return vi ? 'Đang di chuyển' : 'On trip';
    case 'completed': return vi ? 'Đã hoàn thành' : 'Completed';
    case 'cancelled': return vi ? 'Đã hủy' : 'Cancelled';
    default:          return status;
  }
}

/// Pill status badge widget
Widget statusBadge(String status, String lang) {
  final color = statusColor(status);
  final label = statusLabel(status, lang);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: Border.all(color: color.withOpacity(0.3), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppText.captionBold.copyWith(color: color)),
      ],
    ),
  );
}

/// Service type info helper
({IconData icon, String label}) serviceInfo(String serviceType, String lang) {
  final vi = lang == 'vi';
  switch (serviceType) {
    case 'bao-xe':
      return (icon: Icons.directions_car_rounded, label: vi ? 'Bao xe' : 'Private');
    case 'gui-hang':
      return (icon: Icons.local_shipping_rounded, label: vi ? 'Gửi hàng' : 'Delivery');
    default:
      return (icon: Icons.people_alt_rounded, label: vi ? 'Xe ghép' : 'Shared');
  }
}

// ── Custom Painted Omigo Logo Widget ──
class OmigoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.16;

    final Paint paint = Paint()
      ..color = const Color(0xFF10B981) // Mint green color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(0.40); // 0.40 radians clockwise rotation to match the slanted O logo

    final Rect rect = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.70,
      height: h * 0.95,
    );
    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OmigoLogoWidget extends StatelessWidget {
  final double size;
  const OmigoLogoWidget({Key? key, this.size = 60}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: OmigoLogoPainter(),
    );
  }
}
