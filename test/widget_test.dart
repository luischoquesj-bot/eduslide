import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduslide/main.dart';
import 'package:eduslide/core/constants/app_strings.dart';

void main() {
  testWidgets('EduSlideApp renderiza pantalla principal y tarjeta de bienvenida', (WidgetTester tester) async {
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
  });
}
