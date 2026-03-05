import 'package:flutter/material.dart';

class StepCounter extends StatefulWidget {
  final int initialValue;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;
  final Color backgroundColor;
  final Color iconColor;
  final double height;
  final double width;

  const StepCounter({
    super.key,
    this.initialValue = 0,
    this.min = 0,
    this.max = 100,
    this.onChanged,
    this.backgroundColor = const Color(0xFF2196F3),
    this.iconColor = Colors.white,
    this.height = 48,
    this.width = 140,
  });

  @override
  State<StepCounter> createState() => _StepCounterState();
}

class _StepCounterState extends State<StepCounter> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(widget.min, widget.max);
  }

  void _increment() {
    if (_value < widget.max) {
      setState(() => _value++);
      widget.onChanged?.call(_value);
    }
  }

  void _decrement() {
    if (_value > widget.min) {
      setState(() => _value--);
      widget.onChanged?.call(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            icon: Icons.remove,
            onTap: _decrement,
            enabled: _value > widget.min,
            color: widget.iconColor,
          ),
          Text(
            '$_value',
            style: TextStyle(
              color: widget.iconColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          _ActionButton(
            icon: Icons.add,
            onTap: _increment,
            enabled: _value < widget.max,
            color: widget.iconColor,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      color: color,
      disabledColor: color.withOpacity(0.4),
      splashRadius: 22,
    );
  }
}
