import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class CirclePage extends StatefulWidget {
  const CirclePage({super.key});

  @override
  State<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends State<CirclePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController();

  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  // ✅ ADD CONTACT TO CLOUD (Firebase)
  Future<void> _addContact() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isAdding = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.addContact(
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _relationshipController.text.trim(),
      );
      
      if (result == 'success') {
        // Clear form
        _nameController.clear();
        _phoneController.clear();
        _relationshipController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Contact saved to cloud!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $result'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  // ✅ DELETE CONTACT FROM CLOUD
  Future<void> _deleteContact(String contactId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.deleteContact(contactId);
      
      if (result == 'success' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact removed from cloud'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ SHOW ADD CONTACT DIALOG
  void _showAddDialog(Color glassColor, Color textMain, Color textSub, Color accent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: glassColor,
        title: Text('Add Trusted Contact', style: TextStyle(color: textMain)),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textMain),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: textSub),
                    prefixIcon: Icon(Icons.person, color: accent),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textMain),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: textSub),
                    prefixIcon: Icon(Icons.phone, color: accent),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 10) return 'Enter valid phone';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _relationshipController,
                  style: TextStyle(color: textMain),
                  decoration: InputDecoration(
                    labelText: 'Relationship (e.g., Mom, Friend)',
                    labelStyle: TextStyle(color: textSub),
                    prefixIcon: Icon(Icons.family_restroom, color: accent),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _nameController.clear();
              _phoneController.clear();
              _relationshipController.clear();
            },
            child: Text('Cancel', style: TextStyle(color: textSub)),
          ),
          ElevatedButton(
            onPressed: _isAdding ? null : () async {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                await _addContact();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            child: _isAdding 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Dynamic Colors
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppColors.bgDarkStart, AppColors.bgDarkEnd]
          : [AppColors.bgLightStart, AppColors.bgLightEnd],
    );
    final glassColor = isDark ? AppColors.glassDark : AppColors.glassLight;
    final textColorMain = isDark ? AppColors.textDarkMain : AppColors.textLightMain;
    final textColorSub = isDark ? AppColors.textDarkSub : AppColors.textLightSub;
    final accentColor = isDark ? AppColors.primaryBurgundyDark : AppColors.primaryBurgundyLight;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(decoration: BoxDecoration(gradient: bgGradient)),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        'Trusted Circle',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: accentColor,
                        onPressed: authProvider.isSignedIn 
                            ? () => _showAddDialog(glassColor, textColorMain, textColorSub, accentColor)
                            : null,
                      ),
                    ],
                  ),
                ),
                
                // Login Prompt or Contacts List
                Expanded(
                  child: !authProvider.isSignedIn
                      ? _buildLoginPrompt(glassColor, textColorMain, textColorSub, accentColor)
                      : StreamBuilder(
                          stream: authProvider.getContacts(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error: ${snapshot.error}',
                                  style: TextStyle(color: textColorSub),
                                ),
                              );
                            }
                            
                            final contacts = snapshot.data?.docs ?? [];
                            if (contacts.isEmpty) {
                              return _buildEmptyState(glassColor, textColorMain, textColorSub);
                            }
                            
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: contacts.length,
                              itemBuilder: (ctx, i) {
                                final contact = contacts[i].data() as Map<String, dynamic>;
                                final contactId = contacts[i].id;
                                
                                return _buildContactCard(
                                  name: contact['name'] ?? 'Unknown',
                                  relationship: contact['relationship'] ?? '',
                                  phone: contact['phone'] ?? '',
                                  onDelete: () => _deleteContact(contactId),
                                  glassColor: glassColor,
                                  textColorMain: textColorMain,
                                  textColorSub: textColorSub,
                                  accentColor: accentColor,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔒 Login Prompt Widget
  Widget _buildLoginPrompt(Color glassColor, Color textMain, Color textSub, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: accent),
            const SizedBox(height: 24),
            Text(
              'Sign In to Save Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your trusted contacts are saved to the cloud. Sign in to access them on any device.',
              style: TextStyle(fontSize: 13, color: textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to login (adjust path as needed)
                // For now, we'll just show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in from Profile page')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  // 📭 Empty State Widget
  Widget _buildEmptyState(Color glassColor, Color textMain, Color textSub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 64, color: textSub),
            const SizedBox(height: 24),
            Text(
              'No Trusted Contacts Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first trusted contact to start saving them to the cloud.',
              style: TextStyle(fontSize: 13, color: textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(glassColor, textMain, textSub, textMain),
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: textMain,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 👤 Contact Card Widget
  Widget _buildContactCard({
    required String name,
    required String relationship,
    required String phone,
    required VoidCallback onDelete,
    required Color glassColor,
    required Color textColorMain,
    required Color textColorSub,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accentColor.withOpacity(0.2),
          child: Icon(Icons.person, color: accentColor),
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColorMain),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(relationship, style: TextStyle(color: textColorSub, fontSize: 12)),
            Text(phone, style: TextStyle(color: textColorSub, fontSize: 12)),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.riskRed),
          onPressed: onDelete,
        ),
      ),
    );
  }
}