import 'package:flutter/material.dart';

class RainbowGlowButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;
  final double glowIntensity;
  final double animationSpeed;

  const RainbowGlowButton({
    Key? key,
    required this.icon,
    this.size = 60,
    this.onPressed,
    this.glowIntensity = 20,
    this.animationSpeed = 2,
  }) : super(key: key);

  @override
  _RainbowGlowButtonState createState() => _RainbowGlowButtonState();
}

class _RainbowGlowButtonState extends State<RainbowGlowButton>
    with TickerProviderStateMixin {
  late AnimationController _rainbowController;
  late AnimationController _glowController;
  late Animation<double> _rainbowAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Rainbow color animation
    _rainbowController = AnimationController(
      duration: Duration(seconds: (3 / widget.animationSpeed).round()),
      vsync: this,
    );
    _rainbowAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_rainbowController);

    // Glow pulse animation
    _glowController = AnimationController(
      duration: Duration(milliseconds: (1500 / widget.animationSpeed).round()),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _rainbowController.repeat();
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rainbowController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color _getRainbowColor(double progress) {
    // Create smooth rainbow transition
    double hue = (progress * 360) % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 1.0).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rainbowAnimation, _glowAnimation]),
      builder: (context, child) {
        Color currentColor = _getRainbowColor(_rainbowAnimation.value);
        double glowRadius = widget.glowIntensity * _glowAnimation.value;

        return GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: widget.size + (glowRadius * 2),
            height: widget.size + (glowRadius * 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Multiple shadow layers for intense glow
                BoxShadow(
                  color: currentColor.withOpacity(0.6),
                  blurRadius: glowRadius,
                  spreadRadius: glowRadius * 0.3,
                ),
                BoxShadow(
                  color: currentColor.withOpacity(0.3),
                  blurRadius: glowRadius * 1.5,
                  spreadRadius: glowRadius * 0.1,
                ),
                BoxShadow(
                  color: currentColor.withOpacity(0.1),
                  blurRadius: glowRadius * 2,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              width: widget.size,
              height: widget.size,
              margin: EdgeInsets.all(glowRadius),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    currentColor.withOpacity(0.8),
                    currentColor.withOpacity(0.6),
                    currentColor.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
                border: Border.all(
                  color: currentColor.withOpacity(0.9),
                  width: 2,
                ),
              ),
              child: Icon(
                widget.icon,
                size: widget.size * 0.5,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: currentColor,
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdvancedRainbowGlowButton extends StatefulWidget {
  final IconData? icon;
  final String? assetPath;
  final double size;
  final VoidCallback? onPressed;
  final List<Color>? customColors;
  final Duration animationDuration;
  final double maxGlowRadius;

  const AdvancedRainbowGlowButton({
    Key? key,
    this.icon,
    this.assetPath,
    this.size = 60,
    this.onPressed,
    this.customColors,
    this.animationDuration = const Duration(seconds: 3),
    this.maxGlowRadius = 20,
  }) : assert(icon != null || assetPath != null, 'Either icon or assetPath must be provided'),
        super(key: key);

  @override
  _AdvancedRainbowGlowButtonState createState() => _AdvancedRainbowGlowButtonState();
}

class _AdvancedRainbowGlowButtonState extends State<AdvancedRainbowGlowButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _colorAnimation;
  late Animation<double> _scaleAnimation;

  List<Color> get _colors => widget.customColors ?? [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _colorAnimation = Tween<double>(
      begin: 0,
      end: _colors.length.toDouble(),
    ).animate(_controller);

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _interpolateColors(double progress) {
    int index = progress.floor() % _colors.length;
    int nextIndex = (index + 1) % _colors.length;
    double localProgress = progress - progress.floor();

    return Color.lerp(_colors[index], _colors[nextIndex], localProgress) ?? _colors[0];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Color currentColor = _interpolateColors(_colorAnimation.value);
        double scale = _scaleAnimation.value;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size + widget.maxGlowRadius * 2,
            height: widget.size + widget.maxGlowRadius * 2,
            child: CustomPaint(
              painter: RainbowGlowPainter(
                color: currentColor,
                glowRadius: widget.maxGlowRadius,
                progress: _colorAnimation.value,
              ),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onPressed,
                    borderRadius: BorderRadius.circular(widget.size / 2),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentColor.withOpacity(0.3),
                      ),
                      child: widget.assetPath != null
                          ? Image.asset(
                        widget.assetPath!,
                        width: widget.size * 0.25,
                        height: widget.size * 0.25,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                      )
                          : Icon(
                        widget.icon!,
                        size: widget.size * 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RainbowGlowPainter extends CustomPainter {
  final Color color;
  final double glowRadius;
  final double progress;

  RainbowGlowPainter({
    required this.color,
    required this.glowRadius,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - glowRadius * 2) / 2;

    // Create gradient paint for glow effect
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.4),
          color.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + glowRadius));

    canvas.drawCircle(center, radius + glowRadius, paint);
  }

  @override
  bool shouldRepaint(RainbowGlowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.glowRadius != glowRadius;
  }
}