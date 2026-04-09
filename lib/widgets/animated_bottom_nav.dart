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
      margin: const EdgeInsets.only(
        bottom: 20,
        left: 16,
        right: 16,
      ), // ✅ Reduced side margin slightly
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        // ✅ Reduced outer padding to save space
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  child: Padding(
                    // ✅ Reduced gap between items to prevent overflow
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      // ✅ Reduced internal padding to fit text comfortably without overflow
                      // This still gives ~8px buffer around the text (covering the word + extra)
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),

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
                            size: 22, // ✅ Slightly smaller icon to save space
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  return SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(-0.2, 0.0),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeInOut,
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
                                    padding: const EdgeInsets.only(
                                      left: 6,
                                    ), // ✅ Tighter spacing
                                    child: Text(
                                      item.label,
                                      key: ValueKey(item.label),
                                      style: TextStyle(
                                        color: widget.activeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            13, // ✅ Slightly smaller font to fit
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
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
