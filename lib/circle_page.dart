import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CirclePage extends StatefulWidget {
  const CirclePage({super.key});

  @override
  State<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends State<CirclePage> {
  List<Contact> _trustedContacts = [];
  bool _isLoading = false;

  // 🔧 FIX #1: Consistent phone normalization - always returns +91 + last 10 digits
  String _normalizePhone(String raw) {
    // Remove ALL non-digit characters first
    String digits = raw.replaceAll(RegExp(r'\D'), '');

    // Handle Indian numbers: always format as +91 + last 10 digits
    if (digits.length >= 10) {
      // Take last 10 digits to handle cases with/without country code
      String last10 = digits.substring(digits.length - 10);
      return '+91$last10';
    }

    // Fallback for edge cases (should rarely happen with valid contacts)
    return raw.startsWith('+') ? raw : '+91$digits';
  }

  @override
  void initState() {
    super.initState();
    _loadTrustedContacts();
  }

  Future<void> _loadTrustedContacts() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactIds = prefs.getStringList('trusted_contact_ids') ?? [];

      if (contactIds.isNotEmpty) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withThumbnail: false,
        );
        final trusted = contacts
            .where(
              (contact) =>
                  contact.id != null && contactIds.contains(contact.id!),
            )
            .toList();
        if (mounted) {
          setState(() => _trustedContacts = trusted);
        }
      }
    } catch (e) {
      // Silent fail
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addContact() async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) {
      final result = await Permission.contacts.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Contacts permission required')),
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
          .where(
            (c) =>
                c.phones != null &&
                c.phones!.isNotEmpty &&
                c.phones!.any((p) => p.number.trim().isNotEmpty),
          )
          .toList();

      if (contactsWithPhones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No contacts have phone numbers')),
          );
        }
        return;
      }

      _showContactSelectionDialog(contactsWithPhones);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load contacts')));
      }
    }
  }

  void _showContactSelectionDialog(List<Contact> allContacts) {
    List<Contact> filteredContacts = List.from(allContacts);

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: TextField(
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (query) {
              final filtered = allContacts.where((contact) {
                final name = contact.displayName?.toLowerCase() ?? '';
                final phone = contact.phones?.isNotEmpty == true
                    ? contact.phones![0].number.toLowerCase()
                    : '';
                return name.contains(query.toLowerCase()) ||
                    phone.contains(query.toLowerCase());
              }).toList();
              setState(() => filteredContacts = filtered);
            },
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: filteredContacts.isEmpty
                ? Center(child: Text('No contacts found'))
                : ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final name = contact.displayName ?? 'Unknown';
                      final phone = contact.phones?.isNotEmpty == true
                          ? contact.phones![0].number
                          : 'No number';

                      return ListTile(
                        title: Text(name),
                        subtitle: Text(phone),
                        onTap: () {
                          Navigator.of(context, rootNavigator: false).pop();
                          _selectContact(contact);
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  // 🔧 FIX #2: Normalize existing phones before checking for duplicates
  Future<void> _selectContact(Contact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final existingIds = prefs.getStringList('trusted_contact_ids') ?? [];
    final existingPhones =
        prefs.getStringList('emergency_contact_phones') ?? [];

    final contactId = contact.id;
    if (contactId != null && !existingIds.contains(contactId)) {
      existingIds.add(contactId);
      await prefs.setStringList('trusted_contact_ids', existingIds);

      if (contact.phones?.isNotEmpty == true) {
        String normalized = _normalizePhone(contact.phones![0].number);

        // Normalize existing stored phones for accurate comparison
        final existingNormalized = existingPhones.map(_normalizePhone).toSet();

        if (!existingNormalized.contains(normalized)) {
          existingPhones.add(normalized);
          // Keep only first 2 contacts' phones (enforce limit)
          await prefs.setStringList(
            'emergency_contact_phones',
            existingPhones.take(2).toList(),
          );
        }
      }

      if (mounted) {
        setState(() {
          _trustedContacts.add(contact);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${contact.displayName ?? 'Contact'} added')),
        );
      }
    }
  }

  // 🔧 FIX #3: Properly remove phones using normalized comparison + maintain 2-contact limit
  Future<void> _removeContact(Contact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final existingIds = prefs.getStringList('trusted_contact_ids') ?? [];
    final existingPhones =
        prefs.getStringList('emergency_contact_phones') ?? [];

    // Remove by contact ID
    if (contact.id != null) {
      existingIds.remove(contact.id!);
      await prefs.setStringList('trusted_contact_ids', existingIds);
    }

    // Remove ALL phone numbers associated with this contact using normalized comparison
    if (contact.phones?.isNotEmpty == true) {
      // Create set of normalized phones for this contact (handle multiple numbers)
      final contactNormalizedPhones = contact.phones!
          .map((p) => _normalizePhone(p.number))
          .toSet();

      // Remove any stored phone whose normalized version matches
      existingPhones.removeWhere((storedPhone) {
        final normalizedStored = _normalizePhone(storedPhone);
        return contactNormalizedPhones.contains(normalizedStored);
      });

      // 🔧 CRITICAL: After removal, re-enforce the 2-contact limit and save
      await prefs.setStringList(
        'emergency_contact_phones',
        existingPhones.take(2).toList(),
      );
    }

    if (mounted) {
      setState(() {
        _trustedContacts.remove(contact);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.displayName ?? 'Contact'} removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Circle',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.add), onPressed: _addContact),
          // 🔥 TEMPORARY RESET BUTTON — REMOVE AFTER TESTING
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.orange),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('trusted_contact_ids');
              await prefs.remove('emergency_contact_phones');
              if (mounted) {
                setState(() {
                  _trustedContacts.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ All contacts RESET!')),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : _trustedContacts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.person_crop_circle,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Emergency Contacts',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add trusted friends or family',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _trustedContacts.length,
              itemBuilder: (context, index) {
                final contact = _trustedContacts[index];
                final name = contact.displayName ?? 'Unknown';
                final phone = contact.phones?.isNotEmpty == true
                    ? contact.phones![0].number
                    : 'No phone';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.2,
                      ),
                      child: Text(
                        (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(phone),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeContact(contact),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
