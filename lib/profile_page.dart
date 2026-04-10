import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:provider/provider.dart';
import 'package:noor_new/theme/theme_provider.dart';
import 'package:noor_new/theme/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  //  MOCK AUTH STATE
  bool _isLoggedIn = false;
  String _userName = "User";
  String _userEmail = "user@example.com";

  //  MOCK LIVE SHARING STATE
  // bool _isLiveSharingEnabled = false;
  bool _isLoading = false;

  // Simulate Login
  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoggedIn = true;
      _userName = "Dhvani";
      _userEmail = "dhvani@safesprout.com";
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Successfully signed in'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Simulate Logout
Future<void> _handleLogout() async {
  setState(() => _isLoading = true);
  await Future.delayed(const Duration(milliseconds: 500));

  setState(() {
    _isLoggedIn = false;
    _isLoading = false;
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Successfully signed out'),
        backgroundColor: Colors.grey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

  // void _toggleLiveSharing(bool value) {
  //   if (!_isLoggedIn && value) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: const Text('Please sign in to enable Live Location Sharing'),
  //         backgroundColor: Colors.orange,
  //         behavior: SnackBarBehavior.floating,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //       ),
  //     );
  //     return;
  //   }

  //   setState(() {
  //     _isLiveSharingEnabled = value;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Dynamic Theme Colors
    final glassColor = isDark ? AppColors.glassDark : AppColors.glassLight;
    final textColorMain = isDark
        ? AppColors.textDarkMain
        : AppColors.textLightMain;
    final textColorSub = isDark
        ? AppColors.textDarkSub
        : AppColors.textLightSub;
    final accentColor = isDark
        ? AppColors.primaryBurgundyDark
        : AppColors.primaryBurgundyLight;
    final borderColor = Colors.white.withOpacity(0.2);

    return Scaffold(
      body: Stack(
        children: [
          //  1. BLURRED BACKGROUND IMAGE (Replaces Gradient)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 20,
                sigmaY: 20,
              ), // Strong blur for readability
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      isDark ? AppColors.bgDarkImage : AppColors.bgLightImage,
                    ),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    // Optional: Slight overlay to ensure text contrast
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                      BlendMode.softLight,
                    ),
                  ),
                ),
              ),
            ),
          ),

          //  2. Extra Overlay for Readability
          Container(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.white.withOpacity(0.3),
          ),

          //  3. Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Header
                        Text(
                          'My Profile',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textColorMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage safety settings and account',
                          style: TextStyle(fontSize: 14, color: textColorSub),
                        ),
                        const SizedBox(height: 32),

                        // 3. User Info Card
                        if (_isLoggedIn) ...[
                          _buildGlassCard(
                            glassColor: glassColor,
                            borderColor: borderColor,
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: accentColor.withOpacity(
                                        0.2,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: accentColor,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _userName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: textColorMain,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _userEmail,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textColorSub,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Edit Profile coming soon',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit Details'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: accentColor,
                                      side: BorderSide(
                                        color: accentColor.withOpacity(0.3),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          // Login Prompt Card
                          _buildGlassCard(
                            glassColor: glassColor,
                            borderColor: borderColor,
                            isDark: isDark,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 48,
                                  color: accentColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sign in to sync safety data',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColorMain,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Access trusted contacts and live location history from any device.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColorSub,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text(
                                      'Sign In / Sign Up',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 4. Live Location Sharing
                        // _buildGlassCard(
                        //   glassColor: glassColor,
                        //   borderColor: borderColor,
                        //   isDark: isDark,
                        //   child: Column(
                        //     crossAxisAlignment: CrossAxisAlignment.start,
                        //     children: [
                        //       Row(
                        //         children: [
                        //           Icon(
                        //             Icons.share_location,
                        //             color: accentColor,
                        //             size: 24,
                        //           ),
                        //           const SizedBox(width: 12),
                        //           Text(
                        //             'Real-Time Location Sharing',
                        //             style: TextStyle(
                        //               fontWeight: FontWeight.bold,
                        //               fontSize: 16,
                        //               color: textColorMain,
                        //             ),
                        //           ),
                        //         ],
                        //       ),
                        //       const SizedBox(height: 12),
                        //       Text(
                        //         'Allow trusted contacts to see your live location during active journeys.',
                        //         style: TextStyle(
                        //           fontSize: 13,
                        //           color: textColorSub,
                        //           height: 1.4,
                        //         ),
                        //       ),
                        //       const SizedBox(height: 16),
                        //       Row(
                        //         mainAxisAlignment:
                        //             MainAxisAlignment.spaceBetween,
                        //         children: [
                        //           Text(
                        //             _isLiveSharingEnabled
                        //                 ? 'Enabled'
                        //                 : 'Disabled',
                        //             style: TextStyle(
                        //               fontWeight: FontWeight.w600,
                        //               color: _isLiveSharingEnabled
                        //                   ? AppColors.riskGreen
                        //                   : textColorSub,
                        //             ),
                        //           ),
                        //           Transform.scale(
                        //             scale: 0.9,
                        //             child: CupertinoSwitch(
                        //               value: _isLiveSharingEnabled,
                        //               onChanged: _isLoggedIn
                        //                   ? _toggleLiveSharing
                        //                   : null,
                        //               activeColor: accentColor,
                        //               trackColor: Colors.grey.withOpacity(0.3),
                        //             ),
                        //           ),
                        //         ],
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        // const SizedBox(height: 24),

                        // 5. Appearance
                        _buildGlassCard(
                          glassColor: glassColor,
                          borderColor: borderColor,
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.palette,
                                    color: accentColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Appearance',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColorMain,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Dark Mode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColorMain,
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.9,
                                    child: CupertinoSwitch(
                                      value: themeProvider.isDarkMode,
                                      onChanged: (value) {
                                        themeProvider.toggleTheme();
                                      },
                                      activeColor: accentColor,
                                      trackColor: Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 6. Security Actions
                        if (_isLoggedIn)
                          _buildGlassCard(
                            glassColor: glassColor,
                            borderColor: borderColor,
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      color: AppColors.riskRed,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Security',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColorMain,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildActionTile(
                                  icon: Icons.logout,
                                  title: 'Log Out',
                                  subtitle: 'Sign out of this device',
                                  color: AppColors.riskRed,
                                  onTap: _handleLogout,
                                ),
                                const Divider(height: 1, color: Colors.white24),
                                _buildActionTile(
                                  icon: Icons.delete_forever,
                                  title: 'Delete Account',
                                  subtitle: 'Permanently remove all data',
                                  color: AppColors.riskRed,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account deletion requested (Mock)',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  //  Reusable Glass Card Widget
  Widget _buildGlassCard({
    required Widget child,
    required Color glassColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: glassColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  //  Reusable Action Tile
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
      ),
      trailing: Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
      onTap: onTap,
    );
  }
}
