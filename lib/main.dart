import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/screens/workspace_screen.dart';

/// Punto de entrada principal de EduSlide.
/// Configurado para proyectores Android, tablets y pantallas interactivas
/// con orientación horizontal obligatoria y modo inmersivo continuo.
void main() async {
  // Asegurar la inicialización de los bindings del framework de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configuración de pantalla: Forzar orientación horizontal estricta
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 2. Configuración de modo inmersivo completo (oculta barras de estado y navegación del sistema)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const EduSlideApp());
}

/// Aplicación raíz de EduSlide
class EduSlideApp extends StatelessWidget {
  const EduSlideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const WorkspaceScreen(),
    );
  }
}
