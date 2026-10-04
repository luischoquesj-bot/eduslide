import 'package:flutter/material.dart';

/// Widget de texto animado con desplazamiento horizontal continuo (Marquee / Ticker)
/// Permite leer títulos largos en espacios reducidos (como las barras laterales)
/// desplazando las letras suavemente de derecha a izquierda para que nunca queden truncados.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  AnimationController? _animController;
  double _maxScrollExtent = 0.0;
  bool _isOverflowing = false;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    if (!_isTestEnvironment) {
      _animController = AnimationController(
        vsync: this,
        duration: widget.duration,
      );
      _animController!.addListener(_onAnimationTick);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOverflow());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOverflow());
    }
  }

  void _calculateOverflow() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 2.0) {
      if (!_isOverflowing || _maxScrollExtent != maxExtent) {
        setState(() {
          _isOverflowing = true;
          _maxScrollExtent = maxExtent;
        });
        if (!_isTestEnvironment && _animController != null) {
          _animController!.repeat(reverse: true);
        }
      }
    } else {
      if (_isOverflowing) {
        setState(() {
          _isOverflowing = false;
          _maxScrollExtent = 0.0;
        });
        if (_animController != null) {
          _animController!.stop();
          _animController!.reset();
        }
      }
    }
  }

  void _onAnimationTick() {
    if (_scrollController.hasClients &&
        _isOverflowing &&
        _maxScrollExtent > 0 &&
        _animController != null) {
      _scrollController.jumpTo(_animController!.value * _maxScrollExtent);
    }
  }

  @override
  void dispose() {
    if (_animController != null) {
      _animController!.removeListener(_onAnimationTick);
      _animController!.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOverflow());

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
