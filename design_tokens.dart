import 'package:flutter/material.dart';

/// Design tokens — colors, gradients, spacing.
class C {
  static const bg = Color(0xFF070710);
  static const panel = Color(0xFF0D0D1E);
  static const elevated = Color(0xFF131326);
  static const card = Color(0xFF181830);
  static const border = Color(0xFF1E1E3C);
  static const divider = Color(0xFF151530);

  static const gold = Color(0xFFFFBF00);
  static const goldDim = Color(0xFF8A6800);
  static const cyan = Color(0xFF00E5FF);
  static const purple = Color(0xFFBB86FC);
  static const pink = Color(0xFFFF4081);
  static const green = Color(0xFF00E676);
  static const red = Color(0xFFFF1744);
  static const amber = Color(0xFFFFAB00);
  static const blue = Color(0xFF448AFF);
  static const teal = Color(0xFF1DE9B6);

  static const tx1 = Color(0xFFF0F0FF);
  static const tx2 = Color(0xFF8888AA);
  static const tx3 = Color(0xFF44445A);

  static const LinearGradient goldGrad = LinearGradient(
    colors: [Color(0xFFFFBF00), Color(0xFFFF6F00)],
  );
  static const LinearGradient cyanGrad = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
  );
  static const LinearGradient purpleGrad = LinearGradient(
    colors: [Color(0xFFBB86FC), Color(0xFF7C4DFF)],
  );
}
