import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum Utensil {
  oven(
    id: 'oven',
    label: 'Forno',
    assetPath: 'assets/icons/oven.svg',
  ),
  mixer(
    id: 'mixer',
    label: 'Batedeira',
    assetPath: 'assets/icons/mixer.svg',
  ),
  blender(
    id: 'blender',
    label: 'Liquidificador',
    assetPath: 'assets/icons/blender.svg',
  ),
  whisk(
    id: 'whisk',
    label: 'Fouet',
    assetPath: 'assets/icons/whisk.svg',
  ),
  rollingPin(
    id: 'rolling_pin',
    label: 'Rolo de massa',
    assetPath: 'assets/icons/rolling-pin.svg',
  );

  final String id;
  final String label;
  final String assetPath;

  const Utensil({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  // Render SVG icon cleanly with color tinting
  Widget buildIcon({double size = 16, Color? color}) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }

  static Utensil? fromId(String id) {
    for (final u in Utensil.values) {
      if (u.id == id) return u;
    }
    return null;
  }
}