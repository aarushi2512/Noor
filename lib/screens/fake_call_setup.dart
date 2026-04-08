import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:noor_new/theme/app_colors.dart'; // ✅ Import Theme Colors
import '../models/fake_call.dart';
import '../services/fake_call_service.dart';

class FakeCallSetup extends StatefulWidget {
  const FakeCallSetup({super.key});

  @override
  State<FakeCallSetup> createState() => _FakeCallSetupState();
}

class _FakeCallSetupState extends State<FakeCallSetup> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Name');
  final _phoneController = TextEditingController(text: '+91 9123456789');

  DateTime _selectedTime = DateTime.now().add(const Duration(minutes: 2));
  bool _isImmediate = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      final granted = await Permission.scheduleExactAlarm.request();
      if (!granted.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Exact alarm permission denied. Scheduled calls may not work when phone is locked.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.riskOrange,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryBurgundyLight, // ✅ Use Theme Color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = DateTime.now().copyWith(
          hour: picked.hour,
          minute: picked.minute,
          second: 0,
          millisecond: 0,
        );
        if (_selectedTime.isBefore(DateTime.now())) {
          _selectedTime = _selectedTime.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _triggerCall() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final call = _isImmediate
          ? FakeCall.immediate(
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
            )
          : FakeCall.scheduled(
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              scheduledTime: _selectedTime,
            );

      if (_isImmediate) {
        await FakeCallService().triggerImmediateCall(context, call);
      } else {
        await FakeCallService().scheduleCall(call, context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppColors.riskRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ Dynamic Theme Colors
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppColors.bgDarkStart, AppColors.bgDarkEnd]
          : [AppColors.bgLightStart, AppColors.bgLightEnd],
    );
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
    final iconColor = isDark
        ? AppColors.secondaryRoseGold
        : AppColors.secondaryTaupe;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Background
          Container(decoration: BoxDecoration(gradient: bgGradient)),

          // 2. Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Header
                    Text(
                      'Fake Call Setup',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Text(
                    //   'Simulate an incoming call for safety',
                    //   style: TextStyle(fontSize: 14, color: textColorSub),
                    // ),

                    const SizedBox(height: 24),

                    // Info Card (Glass)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: glassColor,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: accentColor,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Uses your device\'s actual ringtone & vibration settings',
                                  style: TextStyle(
                                    color: textColorSub,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Name Input (Glass)
                    _buildGlassTextField(
                      controller: _nameController,
                      label: 'Caller Name',
                      icon: Icons.person_outline,
                      glassColor: glassColor,
                      textColor: textColorMain,
                      subColor: textColorSub,
                      iconColor: iconColor,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter a name'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Phone Input (Glass)
                    _buildGlassTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      glassColor: glassColor,
                      textColor: textColorMain,
                      subColor: textColorSub,
                      iconColor: iconColor,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter a phone number'
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // Timing Card (Glass)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: glassColor,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'When should the call ring?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColorMain,
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildGlassRadioTile(
                                title: 'Call Now',
                                subtitle: 'Ring immediately',
                                icon: Icons.call,
                                value: true,
                                groupValue: _isImmediate,
                                onChanged: (v) =>
                                    setState(() => _isImmediate = v!),
                                accentColor: accentColor,
                                textColor: textColorMain,
                                subColor: textColorSub,
                              ),

                              _buildGlassRadioTile(
                                title: 'Schedule for Later',
                                subtitle:
                                    'Ring at ${_formatTime(_selectedTime)}',
                                icon: Icons.schedule,
                                value: false,
                                groupValue: _isImmediate,
                                onChanged: (v) =>
                                    setState(() => _isImmediate = v!),
                                accentColor: accentColor,
                                textColor: textColorMain,
                                subColor: textColorSub,
                              ),

                              if (!_isImmediate) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _pickTime,
                                    icon: const Icon(
                                      Icons.access_time,
                                      size: 18,
                                    ),
                                    label: const Text('Change Time'),
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
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Main Action Button (Glass Glow)
                    SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _triggerCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: accentColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isImmediate ? Icons.call : Icons.schedule,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isImmediate
                                        ? 'Start Call Now'
                                        : 'Schedule Call',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Reusable Glass TextField
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required Color glassColor,
    required Color textColor,
    required Color subColor,
    required Color iconColor,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(color: textColor, fontSize: 15),
            validator: validator,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: subColor, fontSize: 13),
              prefixIcon: Icon(icon, color: iconColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Reusable Glass Radio Tile
  Widget _buildGlassRadioTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool groupValue,
    required ValueChanged<bool?> onChanged,
    required Color accentColor,
    required Color textColor,
    required Color subColor,
  }) {
    final isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? accentColor : Colors.white.withOpacity(0.1),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? accentColor : subColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: subColor, fontSize: 12)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Radio<bool>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: accentColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  } 

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a • EEE, MMM d').format(time);
  }
}
