import 'package:flutter/material.dart';

/// Paleta de colores principal de EduSlide.
/// Diseñada con estética oscura moderna, alto contraste para proyectores
/// y tonos amigables para el aula escolar.
class AppColors {
  // Fondos principales
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B); // Slate 800
  static const Color surfaceLight = Color(0xFF334155); // Slate 700
  static const Color surfaceElevated = Color(0xFF26334D);

  // Acentos y marcas
  static const Color primary = Color(0xFF38BDF8); // Sky blue moderno
  static const Color primaryHover = Color(0xFF0EA5E9);
  static const Color secondary = Color(0xFF818CF8); // Indigo suave
  static const Color accentGreen = Color(0xFF10B981); // Emerald dinámico
  static const Color accentAmber = Color(0xFFF59E0B); // Amber alert
  static const Color accentRose = Color(0xFFF43F5E); // Rose vibrant

  // Textos y contenido
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Bordes y divisores
  static const Color borderSubtle = Color(0xFF334155);
  static const Color borderHighlight = Color(0xFF475569);

  // Pizarra Blanca
  static const Color whiteboardBg = Color(0xFFF8FAFC);
  static const Color whiteboardGrid = Color(0xFFE2E8F0);
  static const Color whiteboardText = Color(0xFF0F172A);
  static const Color whiteboardStrokeDefault = Color(0xFF1E293B);

  // Pizarra Escolar Oscura (Chalkboard)
  static const Color chalkboardBg = Color(0xFF1A2E26); // Verde pizarra oscuro profundo
  static const Color chalkboardGrid = Color(0xFF233D33);
  static const Color chalkboardText = Color(0xFFF1F5F9);
  static const Color chalkboardStrokeDefault = Color(0xFFE2E8F0); // Tiza blanca
}
