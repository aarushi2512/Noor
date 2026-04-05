import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  NavItem({required this.icon, this.activeIcon, required this.label});
}

class AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavItem> items;
  final Color glassColor;
  final Color activeColor;
  final Color inactiveColor;
  final double blurSigma;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.glassColor = const Color(0xFFFFFFFF),
    this.activeColor = const Color(0xFFFF6B6B),
    this.inactiveColor = const Color(0xFF95A5A6),
    this.blurSigma = 15.0,
  });

  @override
  State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<AnimatedBottomNav> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
      // ✅ REMOVED outer AnimatedContainer to prevent conflicting animations
      child: AnimatedContainer(
        // Only animate padding slightly if needed, but mostly let content drive size
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut, // ✅ Standard curve, no overshoot
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(minWidth: 100),
        decoration: BoxDecoration(
          color: widget.glassColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final isSelected = widget.currentIndex == index;

                return GestureDetector(
                  onTap: () => widget.onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    // ✅ Smooth, standard curve for item expansion
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 16 : 12,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.activeColor.withOpacity(0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected && item.activeIcon != null
                              ? item.activeIcon!
                              : item.icon,
                          color: isSelected
                              ? widget.activeColor
                              : widget.inactiveColor,
                          size: 24,
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          // ✅ Custom transition to slide in smoothly without bounce
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(
                                          -0.3,
                                          0.0,
                                        ), // Smaller slide distance
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves
                                              .easeInOut, // ✅ Match the container curve
                                        ),
                                      ),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                          child: isSelected
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Text(
                                    item.label,
                                    key: ValueKey(item.label),
                                    style: TextStyle(
                                      color: widget.activeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms);
  }
}
