import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:noor_new/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class CirclePage extends StatefulWidget {
  const CirclePage({super.key});

  @override
  State<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends State<CirclePage> {
  List<Contact> _trustedContacts = [];
  bool _isLoading = false;

  // 🔧 Core Logic: Normalize Phone Number
  String _normalizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      String last10 = digits.substring(digits.length - 10);
      return '+91$last10';
    }
    return raw.startsWith('+') ? raw : '+91$digits';
  }

  @override
  void initState() {
    super.initState();
    _loadTrustedContacts();
  }

  // ✅ Load contacts from Firebase Cloud (with local fallback)
  Future<void> _loadTrustedContacts() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // If user is logged in, try to load from Firebase
      if (authProvider.isSignedIn) {
        final snapshot = await authProvider.getContacts().first;
        final contacts = snapshot.docs;
        
        if (contacts.isNotEmpty) {
          final loadedContacts = contacts.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Create a minimal Contact object for display
            return Contact(
              displayName: data['name'] ?? 'Unknown',
              phones: [Phone(_normalizePhone(data['phone'] ?? ''))],
            );
          }).toList();
          
          if (mounted) {
            setState(() => _trustedContacts = loadedContacts);
          }
          return; // Done - loaded from cloud
        }
      }
      
      // Fallback: Load from local SharedPreferences (for offline/old data)
      final prefs = await SharedPreferences.getInstance();
      final contactIds = prefs.getStringList('trusted_contact_ids') ?? [];
      
      if (contactIds.isNotEmpty) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withThumbnail: false,
        );
        final trusted = contacts
            .where((contact) =>
                contact.id != null && contactIds.contains(contact.id!))
            .toList();
        if (mounted) {
          setState(() => _trustedContacts = trusted);
        }
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Add Contact: Opens Phone Contacts App
  Future<void> _addContact() async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) {
      final result = await Permission.contacts.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Contacts permission required'),
              backgroundColor: AppColors.riskOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
      );

      final contactsWithPhones = contacts
          .where((c) =>
              c.phones != null &&
              c.phones!.isNotEmpty &&
              c.phones!.any((p) => p.number.trim().isNotEmpty))
          .toList();

      if (contactsWithPhones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No contacts have phone numbers'),
              backgroundColor: AppColors.secondaryTaupe,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      _showContactSelectionDialog(contactsWithPhones);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load contacts'),
            backgroundColor: AppColors.riskRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ✅ Show Contact Selection Dialog (Your Original Beautiful UI)
  void _showContactSelectionDialog(List<Contact> allContacts) {
    List<Contact> filteredContacts = List.from(allContacts);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? AppColors.glassDark : AppColors.glassLight;
    final textColor = isDark ? AppColors.textDarkMain : AppColors.textLightMain;
    final subColor = isDark ? AppColors.textDarkSub : AppColors.textLightSub;
    final borderColor = Colors.white.withOpacity(0.2);

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          contentPadding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: glassColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search contacts...',
                          hintStyle: TextStyle(color: subColor),
                          prefixIcon: Icon(Icons.search, color: subColor),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                        onChanged: (query) {
                          final filtered = allContacts.where((contact) {
                            final name = contact.displayName?.toLowerCase() ?? '';
                            final phone = contact.phones.isNotEmpty == true
                                ? contact.phones![0].number.toLowerCase()
                                : '';
                            return name.contains(query.toLowerCase()) ||
                                phone.contains(query.toLowerCase());
                          }).toList();
                          setState(() => filteredContacts = filtered);
                        },
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white24),
                    SizedBox(
                      width: double.maxFinite,
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: filteredContacts.isEmpty
                          ? Center(
                              child: Text(
                                'No contacts found',
                                style: TextStyle(color: subColor),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = filteredContacts[index];
                                final name = contact.displayName ?? 'Unknown';
                                final phone = contact.phones.isNotEmpty == true
                                    ? contact.phones![0].number
                                    : 'No number';

                                return ListTile(
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    phone,
                                    style: TextStyle(
                                      color: subColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.of(context, rootNavigator: false)
                                        .pop();
                                    _selectContact(contact);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Select Contact: Save to Firebase Cloud + Local Storage
  Future<void> _selectContact(Contact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final existingIds = prefs.getStringList('trusted_contact_ids') ?? [];
    final existingPhones = prefs.getStringList('emergency_contact_phones') ?? [];

    final contactId = contact.id;
    if (contactId != null && !existingIds.contains(contactId)) {
      // 1. Save to local SharedPreferences (for offline access)
      existingIds.add(contactId);
      await prefs.setStringList('trusted_contact_ids', existingIds);

      if (contact.phones.isNotEmpty == true) {
        String normalized = _normalizePhone(contact.phones![0].number);
        final existingNormalized = existingPhones.map(_normalizePhone).toSet();

        if (!existingNormalized.contains(normalized)) {
          existingPhones.add(normalized);
          await prefs.setStringList(
            'emergency_contact_phones',
            existingPhones.take(2).toList(), // Keep max 2 emergency contacts
          );
        }
      }

      // 2. Save to Firebase Cloud (for cross-device sync)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isSignedIn) {
        await authProvider.addContact(
          contact.displayName ?? 'Unknown',
          contact.phones.isNotEmpty == true ? contact.phones![0].number : '',
          'Trusted Contact', // Default relationship
        );
      }

      if (mounted) {
        setState(() {
          _trustedContacts.add(contact);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.displayName ?? 'Contact'} added'),
            backgroundColor: AppColors.riskGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ✅ Remove Contact: Delete from Firebase + Local
  Future<void> _removeContact(Contact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final existingIds = prefs.getStringList('trusted_contact_ids') ?? [];
    final existingPhones = prefs.getStringList('emergency_contact_phones') ?? [];

    if (contact.id != null) {
      existingIds.remove(contact.id!);
      await prefs.setStringList('trusted_contact_ids', existingIds);
    }

    if (contact.phones.isNotEmpty == true) {
      final contactNormalizedPhones = contact.phones!
          .map((p) => _normalizePhone(p.number))
          .toSet();
      existingPhones.removeWhere(
        (storedPhone) =>
            contactNormalizedPhones.contains(_normalizePhone(storedPhone)),
      );
      await prefs.setStringList(
        'emergency_contact_phones',
        existingPhones.take(2).toList(),
      );
    }

    // Delete from Firebase Cloud
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isSignedIn) {
      // Find the contact in Firebase and delete it
      final snapshot = await authProvider.getContacts().first;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['phone'] == (contact.phones.isNotEmpty == true ? contact.phones![0].number : '')) {
          await authProvider.deleteContact(doc.id);
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _trustedContacts.remove(contact);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${contact.displayName ?? 'Contact'} removed'),
          backgroundColor: AppColors.riskRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ✅ CORE FUNCTION: Reset All Contacts
  Future<void> _resetContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trusted_contact_ids');
    await prefs.remove('emergency_contact_phones');
    
    // Clear from Firebase too
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isSignedIn) {
      final snapshot = await authProvider.getContacts().first;
      for (var doc in snapshot.docs) {
        await authProvider.deleteContact(doc.id);
      }
    }
    
    if (mounted) {
      setState(() {
        _trustedContacts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All contacts reset successfully'),
          backgroundColor: AppColors.secondaryTaupe,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          // ✅ 1. BLURRED BACKGROUND IMAGE (Your Original Design)
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

          // ✅ 2. Extra Overlay for Readability
          Container(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.white.withOpacity(0.3),
          ),

          // ✅ 3. Content
          SafeArea(
            child: Column(
              children: [
                // --- Custom Glass AppBar ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: glassColor,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Circle',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColorMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add, color: accentColor),
                                  onPressed: _addContact,
                                  tooltip: 'Add Contact',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.refresh,
                                    color: AppColors.secondaryTaupe,
                                  ),
                                  onPressed: _resetContacts,
                                  tooltip: 'Reset All Contacts',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // --- List or Empty State ---
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: accentColor),
                        )
                      : _trustedContacts.isEmpty
                          ? _buildEmptyState(
                              glassColor,
                              borderColor,
                              textColorMain,
                              textColorSub,
                              accentColor,
                            )
                          : _buildContactList(
                              glassColor,
                              borderColor,
                              textColorMain,
                              textColorSub,
                              accentColor,
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Empty State Widget (Your Original Design)
  Widget _buildEmptyState(
    Color glassColor,
    Color borderColor,
    Color textMain,
    Color textSub,
    Color accent,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: glassColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: accent.withOpacity(0.5),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Trusted Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + icon to add trusted friends or family',
                    style: TextStyle(fontSize: 14, color: textSub, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text('Add First Contact'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Contact List Widget (Your Original Beautiful Cards)
  Widget _buildContactList(
    Color glassColor,
    Color borderColor,
    Color textMain,
    Color textSub,
    Color accent,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _trustedContacts.length,
      itemBuilder: (context, index) {
        final contact = _trustedContacts[index];
        final name = contact.displayName ?? 'Unknown';
        final phone = contact.phones.isNotEmpty == true
            ? contact.phones![0].number
            : 'No phone';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: glassColor,
                  border: Border.all(color: borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: accent.withOpacity(0.15),
                    child: Text(
                      (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  subtitle: Text(
                    phone,
                    style: TextStyle(color: textSub, fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppColors.riskRed.withOpacity(0.8),
                    ),
                    onPressed: () => _removeContact(contact),
                    tooltip: 'Remove',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}