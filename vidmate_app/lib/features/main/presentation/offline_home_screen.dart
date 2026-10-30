import 'package:flutter/material.dart';
import 'package:vidmate_app/features/discover/presentation/discover_screen.dart';
import 'package:vidmate_app/features/home/presentation/home_screen.dart';
import 'package:vidmate_app/features/library/presentation/library_screen.dart';
import 'package:vidmate_app/features/settings/presentation/settings_screen.dart';

/// Offline mode home screen
/// Shows accessible sections (Home, Library, Settings)
/// with Discover and Download accessible via mock data
class OfflineHomeScreen extends StatefulWidget {
  const OfflineHomeScreen({super.key});

  @override
  State<OfflineHomeScreen> createState() => _OfflineHomeScreenState();
}

class _OfflineHomeScreenState extends State<OfflineHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    DiscoverScreen(), // Shows mock data in offline mode
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    debugPrint('OFFLINE_HOME: build() called, tab=$_currentIndex');
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          // Offline indicator banner (top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24,
              color: Colors.orange.withOpacity(0.9),
              child: const Center(
                child: Text(
                  'OFFLINE MODE - Using Sample Data',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Debug marker (top-right)
          Positioned(
            top: 28,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OFFLINE',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60,
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
            _buildNavItem(2, Icons.folder, 'Library'),
            _buildNavItem(3, Icons.settings, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF6C5CE7) : Colors.white70,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF6C5CE7) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
