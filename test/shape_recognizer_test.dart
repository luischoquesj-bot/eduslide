import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:eduslide/features/whiteboard/domain/utils/shape_recognizer.dart';

void main() {
  group('ShapeRecognizer - Detección Geométrica en Dart Puro', () {
    test('Reconoce una línea recta horizontal con leve imperfección de pulso', () {
      final points = <Offset>[];
      for (double x = 100; x <= 400; x += 10) {
        // Simular pulso humano con leve ruido (< 3 px)
        final noise = (x % 20 == 0) ? 2.0 : -1.5;
        points.add(Offset(x, 200 + noise));
      }

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result.first, equals(points.first));
      expect(result.last, equals(points.last));
    });

    test('Reconoce un círculo dibujado a mano alzada', () {
      final points = <Offset>[];
      const center = Offset(300, 300);
      const radius = 80.0;
      for (int i = 0; i <= 36; i++) {
        final theta = (i * 2 * math.pi) / 36;
        final noise = (i % 3 == 0) ? 3.0 : -2.0;
        points.add(Offset(
          center.dx + (radius + noise) * math.cos(theta),
          center.dy + (radius + noise) * math.sin(theta),
        ));
      }

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNotNull);
      expect(result!.length, greaterThan(20));
      // Verificar que todos los puntos generados equidistan del centro
      for (final p in result) {
        final dist = (p - center).distance;
        expect((dist - radius).abs(), lessThan(7.0));
      }
    });

    test('Reconoce un rectángulo cerrado con 4 esquinas', () {
      final points = <Offset>[
        // Borde superior
        for (double x = 50; x <= 250; x += 20) Offset(x, 100),
        // Borde derecho
        for (double y = 100; y <= 300; y += 20) Offset(250, y),
        // Borde inferior
        for (double x = 250; x >= 50; x -= 20) Offset(x, 300),
        // Borde izquierdo
        for (double y = 300; y >= 100; y -= 20) Offset(50, y),
      ];

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNotNull);
      expect(result!.length, equals(5)); // 4 esquinas + punto de cierre
    });

    test('Reconoce un triángulo cerrado', () {
      final points = <Offset>[
        // Lado 1: base
        for (double x = 100; x <= 300; x += 20) Offset(x, 400),
        // Lado 2: diagonal subiendo
        for (double t = 0; t <= 1.0; t += 0.1) Offset(300 - 100 * t, 400 - 200 * t),
        // Lado 3: diagonal bajando
        for (double t = 0; t <= 1.0; t += 0.1) Offset(200 - 100 * t, 200 + 200 * t),
      ];

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNotNull);
      expect(result!.length, equals(4)); // 3 vértices + punto de cierre
    });

    test('Devuelve null para garabatos libres sin forma geométrica clara (preserva dibujo libre)', () {
      final points = <Offset>[
        const Offset(10, 10),
        const Offset(50, 80),
        const Offset(20, 150),
        const Offset(90, 60),
        const Offset(120, 200),
        const Offset(30, 250),
      ];

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNull);
    });

    test('Devuelve null para puntos insuficientes o trazos minúsculos', () {
      final points = <Offset>[
        const Offset(10, 10),
        const Offset(12, 12),
      ];

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNull);
    });
  });
}
