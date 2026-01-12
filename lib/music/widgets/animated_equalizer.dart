import 'dart:math';
import 'package:flutter/material.dart';

/// Animated equalizer bars that pulse to indicate playback
/// Shows 4 bars with random heights animating up and down
class AnimatedEqualizer extends StatefulWidget {
  final Color color;
  final double size;
  final bool isPlaying;

  const AnimatedEqualizer({
    super.key,
    required this.color,
    this.size = 16.0,
    this.isPlaying = true,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controllers = List.generate(4, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + _random.nextInt(400)),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with staggered delays
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted && widget.isPlaying) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        for (var controller in _controllers) {
          controller.repeat(reverse: true);
        }
      } else {
        for (var controller in _controllers) {
          controller.stop();
          controller.value = 0.3;
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: widget.size / 6,
                height: widget.size * _animations[index].value,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.size / 12),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
