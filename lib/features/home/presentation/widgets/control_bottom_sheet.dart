import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Modos de distribución de pantalla interactiva en EduSlide
enum ScreenDistributionMode {
  standard801010, // 10% Izq | 80% Centro | 10% Der
  full100, // 100% Libre para pizarra o presentación
  split5050, // 50 / 50 Dividida (Pizarra y Material)
  split7525, // 75 / 25 Enfoque prioritario
}

/// Menú inferior emergente con configuración de diseño de pantalla,
/// conexión con el mando a distancia EduSlide Control y firma oficial.
/// Totalmente responsivo con cálculos porcentuales y scroll interno para prevenir desbordamientos.
class ControlBottomSheet extends StatefulWidget {
  final ScreenDistributionMode currentLayout;
  final ValueChanged<ScreenDistributionMode> onLayoutChanged;
  final bool isRemoteConnected;
  final ValueChanged<bool> onRemoteToggled;
  final double currentSplitRatio;
  final ValueChanged<double>? onSplitRatioChanged;
  final bool isResourceOnLeft;
  final ValueChanged<bool>? onResourceSideChanged;
  final bool hasActiveResource;
  final VoidCallback? onCloseResource;

  const ControlBottomSheet({
    super.key,
    required this.currentLayout,
    required this.onLayoutChanged,
    required this.isRemoteConnected,
    required this.onRemoteToggled,
    this.currentSplitRatio = 0.5,
    this.onSplitRatioChanged,
    this.isResourceOnLeft = false,
    this.onResourceSideChanged,
    this.hasActiveResource = false,
    this.onCloseResource,
  });

  static Future<void> show(
    BuildContext context, {
    required ScreenDistributionMode currentLayout,
    required ValueChanged<ScreenDistributionMode> onLayoutChanged,
    required bool isRemoteConnected,
    required ValueChanged<bool> onRemoteToggled,
    double currentSplitRatio = 0.5,
    ValueChanged<double>? onSplitRatioChanged,
    bool isResourceOnLeft = false,
    ValueChanged<bool>? onResourceSideChanged,
    bool hasActiveResource = false,
    VoidCallback? onCloseResource,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ControlBottomSheet(
        currentLayout: currentLayout,
        onLayoutChanged: onLayoutChanged,
        isRemoteConnected: isRemoteConnected,
        onRemoteToggled: onRemoteToggled,
        currentSplitRatio: currentSplitRatio,
        onSplitRatioChanged: onSplitRatioChanged,
        isResourceOnLeft: isResourceOnLeft,
        onResourceSideChanged: onResourceSideChanged,
        hasActiveResource: hasActiveResource,
        onCloseResource: onCloseResource,
      ),
    );
  }

  @override
  State<ControlBottomSheet> createState() => _ControlBottomSheetState();
}

class _ControlBottomSheetState extends State<ControlBottomSheet> {
  late ScreenDistributionMode _selectedLayout;
  late bool _remoteConnected;
  late double _selectedRatio;
  late bool _resourceOnLeft;

  @override
  void initState() {
    super.initState();
    _selectedLayout = widget.currentLayout;
    _remoteConnected = widget.isRemoteConnected;
    _selectedRatio = widget.currentSplitRatio;
    _resourceOnLeft = widget.isResourceOnLeft;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;

    // Dimensiones y espaciados calculados porcentualmente
    final sheetMaxHeight = screenHeight * 0.88;
    final horizontalPadding = (screenWidth * 0.025).clamp(16.0, 28.0);
    final verticalSpacing = (screenHeight * 0.02).clamp(10.0, 18.0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: sheetMaxHeight,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderHighlight, width: 1.5),
          left: BorderSide(color: AppColors.borderHighlight, width: 1.5),
          right: BorderSide(color: AppColors.borderHighlight, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Barra de arrastre superior (fija)
            Padding(
              padding: EdgeInsets.only(top: (screenHeight * 0.015).clamp(8.0, 14.0)),
              child: Center(
                child: Container(
                  width: (screenWidth * 0.06).clamp(36.0, 56.0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderHighlight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // 2. Cabecera fija con título y botón de cierre
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                (screenHeight * 0.012).clamp(6.0, 12.0),
                horizontalPadding,
                (screenHeight * 0.01).clamp(4.0, 10.0),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      AppStrings.controlMenuTitle,
                      style: AppTextStyles.sectionTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cerrar menú',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),

            // 3. Contenido scrolleable para prevenir desbordamientos en cualquier resolución
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalSpacing * 0.8,
                  horizontalPadding,
                  verticalSpacing,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título de sección de distribución
                    Text(
                      AppStrings.screenDistribution,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: (screenHeight * 0.028).clamp(12.5, 14.5),
                      ),
                    ),
                    SizedBox(height: verticalSpacing * 0.6),

                    // Selector de distribución de pantalla
                    _buildLayoutSelector(screenWidth, screenHeight),
                    SizedBox(height: verticalSpacing),

                    // Configuración del recurso activo (100%, 75%, 50% y lado Izq/Der)
                    if (widget.hasActiveResource) ...[
                      _buildResourceConfiguration(screenWidth, screenHeight),
                      SizedBox(height: verticalSpacing * 0.5),
                    ],

                    // Tarjeta de Conexión de Mando (EduSlide Control)
                    _buildRemoteControlOption(screenWidth, screenHeight),
                    SizedBox(height: verticalSpacing),

                    // Divisor y Pie oficial discreto con cálculos porcentuales
                    const Divider(color: AppColors.borderSubtle),
                    SizedBox(height: verticalSpacing * 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.school_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            AppStrings.credits,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w600,
                              fontSize: (screenHeight * 0.024).clamp(10.0, 12.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opciones de cuadrícula de layout con soporte porcentual y responsivo
  Widget _buildLayoutSelector(double screenWidth, double screenHeight) {
    final options = [
      _LayoutOption(
        mode: ScreenDistributionMode.full100,
        title: AppStrings.layoutFull,
        icon: Icons.fullscreen_rounded,
        description: 'Pizarra al 100% de la pantalla',
      ),
      _LayoutOption(
        mode: ScreenDistributionMode.split5050,
        title: AppStrings.layoutSplit5050,
        icon: Icons.vertical_split_rounded,
        description: 'Lienzo y recursos al 50%',
      ),
      _LayoutOption(
        mode: ScreenDistributionMode.split7525,
        title: AppStrings.layoutSplit7525,
        icon: Icons.view_sidebar_rounded,
        description: '75% Pizarra / 25% Panel',
      ),
      _LayoutOption(
        mode: ScreenDistributionMode.standard801010,
        title: 'Estándar (10/80/10)',
        icon: Icons.view_column_rounded,
        description: 'Espacio de trabajo triple',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final use2x2 = constraints.maxWidth < 560;

        Widget buildItem(_LayoutOption opt) {
          final isSelected = _selectedLayout == opt.mode;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedLayout = opt.mode;
              });
              widget.onLayoutChanged(opt.mode);
              // Cierra automáticamente la ventana de Configuración al seleccionar la opción
              Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: (screenHeight * 0.015).clamp(8.0, 12.0),
                horizontal: 4,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.surfaceLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.borderSubtle,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: (screenHeight * 0.04).clamp(18.0, 24.0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (screenHeight * 0.022).clamp(10.0, 11.5),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    opt.description,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (screenHeight * 0.018).clamp(8.0, 9.5),
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (use2x2) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: buildItem(options[0])),
                  const SizedBox(width: 8),
                  Expanded(child: buildItem(options[1])),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: buildItem(options[2])),
                  const SizedBox(width: 8),
                  Expanded(child: buildItem(options[3])),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: buildItem(options[i])),
            ],
          ],
        );
      },
    );
  }

  /// Configuración visual del recurso didáctico (100%, 75%, 50% y lado Izq/Der)
  Widget _buildResourceConfiguration(double screenWidth, double screenHeight) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.aspect_ratio_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Tamaño del Recurso Activo',
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: (screenHeight * 0.026).clamp(12.0, 14.0),
                ),
              ),
              const Spacer(),
              if (widget.onCloseResource != null)
                InkWell(
                  onTap: () {
                    widget.onCloseResource?.call();
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 12, color: AppColors.accentRose),
                        SizedBox(width: 3),
                        Text(
                          'Cerrar Recurso',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentRose,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Botones de 100%, 75%, 50%
          Row(
            children: [
              Expanded(
                child: _buildRatioCard(
                  title: '100% Pantalla',
                  subtitle: 'Ocupa todo el centro',
                  ratio: 1.0,
                  icon: Icons.fullscreen_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildRatioCard(
                  title: '75% Prioritario',
                  subtitle: '75% Recurso / 25% Pizarra',
                  ratio: 0.75,
                  icon: Icons.view_sidebar_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildRatioCard(
                  title: '50% Dividido',
                  subtitle: '50% Recurso / 50% Pizarra',
                  ratio: 0.50,
                  icon: Icons.vertical_split_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Selector de Lado (Izquierda / Derecha)
          Row(
            children: [
              const Text(
                'Posición del recurso:',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              _buildSideChip(label: 'Izquierda', isLeft: true),
              const SizedBox(width: 6),
              _buildSideChip(label: 'Derecha', isLeft: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioCard({
    required String title,
    required String subtitle,
    required double ratio,
    required IconData icon,
  }) {
    final isSelected = (_selectedRatio - ratio).abs() < 0.05;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRatio = ratio;
        });
        widget.onSplitRatioChanged?.call(ratio);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.0,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideChip({required String label, required bool isLeft}) {
    final isSelected = _resourceOnLeft == isLeft;
    return InkWell(
      onTap: () {
        setState(() {
          _resourceOnLeft = isLeft;
        });
        widget.onResourceSideChanged?.call(isLeft);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Tarjeta interactiva de conexión de EduSlide Control
  Widget _buildRemoteControlOption(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (screenWidth * 0.02).clamp(12.0, 18.0),
        vertical: (screenHeight * 0.016).clamp(10.0, 14.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _remoteConnected
              ? AppColors.accentGreen.withValues(alpha: 0.7)
              : AppColors.borderSubtle,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Icono del mando
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _remoteConnected
                  ? AppColors.accentGreen.withValues(alpha: 0.2)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings_remote_rounded,
              color: _remoteConnected
                  ? AppColors.accentGreen
                  : AppColors.textSecondary,
              size: (screenHeight * 0.042).clamp(18.0, 22.0),
            ),
          ),
          const SizedBox(width: 12),

          // Textos del mando
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      AppStrings.connectRemote,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: (screenHeight * 0.028).clamp(12.0, 14.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _remoteConnected
                            ? AppColors.accentGreen.withValues(alpha: 0.2)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _remoteConnected ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _remoteConnected
                              ? AppColors.accentGreen
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _remoteConnected
                      ? 'Conectado a EduSlide Control (Señal 98% • Latencia 5ms)'
                      : AppStrings.remoteStatusDisconnected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: _remoteConnected
                        ? AppColors.accentGreen
                        : AppColors.textMuted,
                    fontSize: (screenHeight * 0.022).clamp(9.5, 11.0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Switch de conexión
          Switch(
            value: _remoteConnected,
            activeThumbColor: AppColors.accentGreen,
            activeTrackColor: AppColors.accentGreen.withValues(alpha: 0.3),
            onChanged: (val) {
              setState(() {
                _remoteConnected = val;
              });
              widget.onRemoteToggled(val);
            },
          ),
        ],
      ),
    );
  }
}

class _LayoutOption {
  final ScreenDistributionMode mode;
  final String title;
  final IconData icon;
  final String description;

  _LayoutOption({
    required this.mode,
    required this.title,
    required this.icon,
    required this.description,
  });
}
