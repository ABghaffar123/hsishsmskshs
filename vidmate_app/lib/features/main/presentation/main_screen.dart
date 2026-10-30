import 'package:flutter/material.dart';

import 'package:vidmate_app/features/home/presentation/home_screen.dart';
import 'package:vidmate_app/features/discover/presentation/discover_screen.dart';
import 'package:vidmate_app/features/downloads/presentation/downloads_screen.dart';
import 'package:vidmate_app/features/library/presentation/library_screen.dart';
import 'package:vidmate_app/features/settings/presentation/settings_screen.dart';

/// Main Screen for VidiMate with bottom navigation and swipe gestures
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    DiscoverScreen(),
    DownloadsScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  // Swipe detection
  double _swipeStart = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('MAIN_SCREEN: initState - online mode active');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MAIN_SCREEN: build() called for tab $_currentIndex');
    // Determine swipe minimum distance
    final minSwipeDistance = MediaQuery.of(context).size.width * 0.3;

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragStart: (details) {
              _swipeStart = details.globalPosition.dx;
            },
            onHorizontalDragUpdate: (details) {
              // Update during drag
            },
            onHorizontalDragEnd: (details) {
              final dragDistance = details.globalPosition.dx - _swipeStart;
              // Minimum swipe distance is 30% of screen width
              if (dragDistance.abs() > minSwipeDistance) {
                setState(() {
                  if (dragDistance > 0) {
                    // Swipe right -> previous section
                    _currentIndex =
                        _currentIndex > 0 ? _currentIndex - 1 : _currentIndex;
                  } else {
                    // Swipe left -> next section
                    _currentIndex = _currentIndex < _screens.length - 1
                        ? _currentIndex + 1
                        : _currentIndex;
                  }
                });
              }
            },
            child: _screens[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: GestureDetector(
        onHorizontalDragEnd: (_) {
          // Prevent bottom nav interaction during swipe
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF171922),
              border: Border(
                top: BorderSide(color: const Color(0xFF3A3D4F), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home, 'Home'),
                _buildNavItem(1, Icons.explore, 'Discover'),
                _buildNavItem(2, Icons.download, 'Downloads'),
                _buildNavItem(3, Icons.folder, 'Library'),
                _buildNavItem(4, Icons.settings, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(index),
        borderRadius: BorderRadius.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF6C5CE7)
                  : Colors.white70,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF6C5CE7)
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}
