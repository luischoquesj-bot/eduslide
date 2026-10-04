import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduslide/main.dart';
import 'package:eduslide/core/constants/app_strings.dart';

void main() {
  testWidgets('EduSlideApp renderiza pantalla principal y tarjeta de bienvenida en proyector', (WidgetTester tester) async {
    // Configurar tamaño horizontal típico de proyector / pantalla interactiva (1920x1080)
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Arrancar la app
    await tester.pumpWidget(const EduSlideApp());
    await tester.pumpAndSettle();

    // Validar presencia de textos clave de bienvenida
    expect(find.text(AppStrings.welcomeTitle), findsOneWidget);
    expect(find.text(AppStrings.startFreeWhiteboard), findsOneWidget);
    expect(find.text(AppStrings.exploreMaterials), findsOneWidget);
    // Validar presencia del botón compacto de Enlazar Control (ícono QR) en la barra flotante
    expect(find.byIcon(Icons.qr_code_rounded), findsOneWidget);
  });

  testWidgets('EduSlideApp renderiza lanzador móvil y opciones en pantalla vertical de smartphone', (WidgetTester tester) async {
    // Configurar tamaño vertical típico de teléfono móvil (390x844)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const EduSlideApp());
    await tester.pumpAndSettle();

    // Validar las dos opciones requeridas y créditos pedagógicos
    expect(find.text('Usar como mando'), findsOneWidget);
    expect(find.text('Usar HDMI o Duplicador'), findsOneWidget);
    expect(find.text('EduProjects BO Educación y Tecnología'), findsOneWidget);
    expect(find.text('Desarrollado por Prof. Luis Choque'), findsOneWidget);
  });
}
