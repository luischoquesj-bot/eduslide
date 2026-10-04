import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/screens/workspace_screen.dart';
import 'features/remote_control/presentation/screens/mobile_launcher_screen.dart';

/// Punto de entrada principal de EduSlide.
/// Detecta automáticamente el tipo de dispositivo al iniciar:
/// 1. Proyectores / Pantallas grandes: Inicia directamente en horizontal en WorkspaceScreen con WebSocket activo.
/// 2. Teléfonos Móviles: Presenta MobileLauncherScreen con opciones pedagógicas (Mando o HDMI).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Permitir orientaciones flexibles al inicio para evaluar las proporciones del dispositivo
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const EduSlideApp());
}

/// Aplicación raíz de EduSlide con soporte multi-dispositivo desacoplado
class EduSlideApp extends StatelessWidget {
  const EduSlideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DeviceAdaptiveLauncher(),
    );
  }
}

/// Selector adaptativo de pantalla al inicio según el factor de forma del dispositivo
class DeviceAdaptiveLauncher extends StatelessWidget {
  const DeviceAdaptiveLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    // Detección de dispositivo:
    // Si la orientación es vertical (ancho < alto) y el ancho es típico de smartphone (< 600 dp),
    // se activa la interfaz móvil para control remoto o duplicador.
    // En caso contrario (proyectores, pizarras táctiles, smart TVs o tablets horizontales),
    // se inicia directamente el espacio de trabajo inmersivo.
    final bool isMobilePhone = size.width < size.height && size.width < 600;

    if (isMobilePhone) {
      return const MobileLauncherScreen();
    } else {
      return const WorkspaceScreen();
    }
  }
}
