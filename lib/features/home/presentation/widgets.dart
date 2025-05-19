import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomNavBarItem {
  final IconData icon;
  final String label;

  CustomNavBarItem({required this.icon, required this.label});
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<CustomNavBarItem> items;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  double _getIconScale(int index) {
    int diff = (currentIndex - index).abs();
    if (diff == 0) return 1.4;
    if (diff == 1) return 1.2;
    if (diff == 2) return 0.8;
    return 0.8;
  }

  double _getBackgroundScale(int index) {
    int diff = (currentIndex - index).abs();
    if (diff == 0) return 1.2;
    if (diff == 1) return 1.0;
    if (diff == 2) return 0.8;
    return 0.6;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        final velocity = details.primaryVelocity!;
        if (velocity < -200 && currentIndex < items.length - 1) {
          onTap(currentIndex + 1);
        } else if (velocity > 200 && currentIndex > 0) {
          onTap(currentIndex - 1);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            double iconScale = _getIconScale(index);
            double bgScale = _getBackgroundScale(index);
            bool isSelected = currentIndex == index;
            return GestureDetector(
              onTap: () => onTap(index),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1.0, end: iconScale),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutExpo,
                builder: (context, iconValue, child) {
                  return Transform.scale(
                    scale: iconValue,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 1.0, end: bgScale),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      builder: (context, bgValue, child) => Transform.scale(
                        scale: bgValue,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.white : Colors.transparent,
                            boxShadow: isSelected
                                ? [
                              const BoxShadow(
                                color: Colors.black26,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              )
                            ]
                                : [],
                          ),
                          child: Icon(
                            items[index].icon,
                            size: 26,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ),
    );
  }
}

extension NavigationServiceExtension on BuildContext {
  int get currentTabIndex {
    final location = GoRouter.of(this).location;
    final paths = ['/location', '/info', '/lock', '/scale', '/notifications'];
    return paths.indexWhere((path) => location.startsWith(path)).clamp(0, paths.length - 1);
  }

  void goToTab(int index) {
    final paths = ['/location', '/info', '/lock', '/scale', '/notifications'];
    if (index >= 0 && index < paths.length) {
      GoRouter.of(this).go(paths[index]);
    }
  }
}