import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:noor_new/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B1B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Info',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Name', 'Not set', isDark),
                _buildInfoRow('Age', 'Not set', isDark),
                _buildInfoRow('Phone', 'Not set', isDark),
                _buildInfoRow('Email', 'Not set', isDark),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE57171),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 32,
                      ),
                    ),
                    child: const Text('Edit Profile'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Dark Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B1B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dark Mode',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dark Mode'),
                    Switch(
                      value: context.watch<ThemeProvider>().isDarkMode,
                      onChanged: (value) {
                        context.read<ThemeProvider>().toggleTheme();
                      },
                      activeTrackColor: const Color(0xFFE57171),
                      activeThumbColor: Colors.white,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: isDark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Security Section
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B1B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Security',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Color(0xFFE57171)),
                  ),
                  onTap: () {},
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(color: Color(0xFFE57171)),
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF171212),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : const Color(0xFF5C4A4A),
          ),
        ),
      ],
    );
  }
}
