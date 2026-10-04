import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tipo de figura geométrica reconocida por [ShapeRecognizer].
enum RecognizedShapeType {
  line,
  circle,
  ellipse,
  rectangle,
  triangle,
}

/// Resultado del reconocimiento geométrico inteligente.
class RecognizedShape {
  final RecognizedShapeType type;
  final List<Offset> points;
  final Rect bounds;

  const RecognizedShape({
    required this.type,
    required this.points,
    required this.bounds,
  });
}

/// Utilidad matemática desacoplada en Dart puro para el reconocimiento y auto-corrección
/// de figuras geométricas en la pizarra mediante el gesto "Draw & Hold".
///
/// Optimizado para proyectores y dispositivos táctiles de recursos limitados (1 GB - 2 GB RAM).
class ShapeRecognizer {
  /// Analiza los puntos acumulados de un trazo a mano alzada.
  /// Si detecta una figura geométrica con alta certeza, devuelve la lista de puntos
  /// de la figura geométrica ideal; de lo contrario retorna `null` para preservar el trazo libre.
  static List<Offset>? recognize(List<Offset> rawPoints) {
    if (rawPoints.length < 5) return null;

    // 1. Filtrar puntos redundantes muy cercanos (< 2.5 px) para acelerar cálculos
    final List<Offset> points = [rawPoints.first];
    for (int i = 1; i < rawPoints.length; i++) {
      if ((rawPoints[i] - points.last).distanceSquared >= 6.25) {
        points.add(rawPoints[i]);
      }
    }
    if (points.length < 4) return null;

    // 2. Calcular longitud total del trazo y distancia directa origen-destino
    double pathLength = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      pathLength += (points[i + 1] - points[i]).distance;
    }

    final Offset start = points.first;
    final Offset end = points.last;
    final double directDistance = (end - start).distance;

    // =========================================================================
    // A. LÍNEA RECTA
    // =========================================================================
    if (directDistance >= 28.0) {
      final double lineTolMax = math.max(16.0, directDistance * 0.12);
      final double lineTolAvg = math.max(8.0, directDistance * 0.06);

      double maxDev = 0.0;
      double sumDev = 0.0;
      bool isStraight = true;

      for (final p in points) {
        final dev = _perpendicularDistanceToSegment(p, start, end);
        if (dev > lineTolMax) {
          isStraight = false;
          break;
        }
        if (dev > maxDev) maxDev = dev;
        sumDev += dev;
      }

      final double avgDev = sumDev / points.length;
      final double lengthRatio = pathLength / directDistance;

      if (isStraight && avgDev <= lineTolAvg && lengthRatio <= 1.25) {
        // Línea recta perfecta entre el origen y el destino
        return [start, end];
      }
    }

    // =========================================================================
    // B. EVALUACIÓN DE FIGURA CERRADA (Círculo, Elipse, Rectángulo, Triángulo)
    // =========================================================================
    final bool isClosed = directDistance <= 45.0 || (directDistance / pathLength < 0.22);
    if (!isClosed) return null;

    // Bounding Box y Centroide
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    double sumX = 0.0;
    double sumY = 0.0;

    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
      sumX += p.dx;
      sumY += p.dy;
    }

    final double width = maxX - minX;
    final double height = maxY - minY;
    if (width < 24.0 || height < 24.0) return null;

    final Offset centroid = Offset(sumX / points.length, sumY / points.length);

    // =========================================================================
    // C. POLÍGONOS (Triángulo y Rectángulo / Cuadrado) CON ALGORITMO RDP
    // =========================================================================
    final double epsilon = math.max(10.0, math.min(width, height) * 0.12);
    final simplified = _ramerDouglasPeucker(points, epsilon);

    // Triángulo: 3 vértices principales (+ cierre = 4 puntos)
    if (simplified.length == 4) {
      final double polyArea = _shoelaceArea(simplified);
      if (polyArea > 0) {
        return [
          simplified[0],
          simplified[1],
          simplified[2],
          simplified[0],
        ];
      }
    }

    // Rectángulo / Cuadrado: 4 vértices principales (+ cierre = 5 puntos)
    if (simplified.length == 5) {
      // Verificar si encaja con la caja delimitadora (axis-aligned box)
      final double boxArea = width * height;
      final double polyArea = _shoelaceArea(simplified);
      if (polyArea > 0 && (polyArea / boxArea) >= 0.70) {
        // Si el ratio ancho/alto es cercano a 1, enderezar como Cuadrado
        if ((width - height).abs() <= math.max(width, height) * 0.18) {
          final double side = (width + height) / 2.0;
          final double half = side / 2.0;
          return [
            Offset(centroid.dx - half, centroid.dy - half),
            Offset(centroid.dx + half, centroid.dy - half),
            Offset(centroid.dx + half, centroid.dy + half),
            Offset(centroid.dx - half, centroid.dy + half),
            Offset(centroid.dx - half, centroid.dy - half),
          ];
        }
        // Rectángulo exacto con bordes alineados
        return [
          Offset(minX, minY),
          Offset(maxX, minY),
          Offset(maxX, maxY),
          Offset(minX, maxY),
          Offset(minX, minY),
        ];
      }
    }

    // =========================================================================
    // D. CÍRCULO O ELIPSE (Curvatura continua sin vértices marcados)
    // =========================================================================
    double sumR = 0.0;
    for (final p in points) {
      sumR += (p - centroid).distance;
    }
    final double meanR = sumR / points.length;

    double sumRDev = 0.0;
    for (final p in points) {
      sumRDev += ((p - centroid).distance - meanR).abs();
    }
    final double avgRDev = sumRDev / points.length;
    final double aspectRatio = width / height;

    // Reconocimiento de Círculo Regular
    if (aspectRatio >= 0.75 && aspectRatio <= 1.30 && (avgRDev / meanR) <= 0.20) {
      final double radius = (width + height) / 4.0;
      return _generateCirclePoints(centroid, radius, 44);
    }

    // Reconocimiento de Elipse
    final double a = width / 2.0;
    final double b = height / 2.0;
    if (a >= 15.0 && b >= 15.0) {
      double sumEllipseError = 0.0;
      for (final p in points) {
        final dx = p.dx - centroid.dx;
        final dy = p.dy - centroid.dy;
        final normalized = (dx * dx) / (a * a) + (dy * dy) / (b * b);
        sumEllipseError += (normalized - 1.0).abs();
      }
      final double avgEllipseError = sumEllipseError / points.length;
      if (avgEllipseError <= 0.20) {
        return _generateEllipsePoints(centroid, a, b, 44);
      }
    }

    return null;
  }

  /// Distancia perpendicular mínima de un punto `p` a un segmento `a -> b`.
  static double _perpendicularDistanceToSegment(Offset p, Offset a, Offset b) {
    final double dx = b.dx - a.dx;
    final double dy = b.dy - a.dy;
    final double lenSq = dx * dx + dy * dy;
    if (lenSq == 0.0) return (p - a).distance;

    final double t = math.max(0.0, math.min(1.0, ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq));
    final Offset projection = Offset(a.dx + t * dx, a.dy + t * dy);
    return (p - projection).distance;
  }

  /// Genera puntos poligonales de un círculo perfecto.
  static List<Offset> _generateCirclePoints(Offset center, double radius, int segments) {
    final List<Offset> pts = [];
    final double step = (2.0 * math.pi) / segments;
    for (int i = 0; i <= segments; i++) {
      final double theta = i * step;
      pts.add(Offset(
        center.dx + radius * math.cos(theta),
        center.dy + radius * math.sin(theta),
      ));
    }
    return pts;
  }

  /// Genera puntos poligonales de una elipse regular.
  static List<Offset> _generateEllipsePoints(Offset center, double a, double b, int segments) {
    final List<Offset> pts = [];
    final double step = (2.0 * math.pi) / segments;
    for (int i = 0; i <= segments; i++) {
      final double theta = i * step;
      pts.add(Offset(
        center.dx + a * math.cos(theta),
        center.dy + b * math.sin(theta),
      ));
    }
    return pts;
  }

  /// Algoritmo Ramer-Douglas-Peucker para simplificación vectorial de polígonos.
  static List<Offset> _ramerDouglasPeucker(List<Offset> pts, double epsilon) {
    if (pts.length <= 2) return List.from(pts);

    double maxDist = 0.0;
    int index = 0;

    for (int i = 1; i < pts.length - 1; i++) {
      final d = _perpendicularDistanceToSegment(pts[i], pts.first, pts.last);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _ramerDouglasPeucker(pts.sublist(0, index + 1), epsilon);
      final right = _ramerDouglasPeucker(pts.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [pts.first, pts.last];
    }
  }

  /// Cálculo del área de un polígono cerrado mediante la fórmula del cordón (Shoelace).
  static double _shoelaceArea(List<Offset> pts) {
    if (pts.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < pts.length; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % pts.length];
      area += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    return (area / 2.0).abs();
  }
}
