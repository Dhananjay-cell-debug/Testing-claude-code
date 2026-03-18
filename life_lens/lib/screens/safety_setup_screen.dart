import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';
import '../models/trusted_contact.dart';
import '../utils/constants.dart';

/// Add/edit/delete trusted emergency contacts.
/// Max 3 contacts. Priority = order they are called.
class SafetySetupScreen extends StatefulWidget {
  const SafetySetupScreen({super.key});

  @override
  State<SafetySetupScreen> createState() => _SafetySetupScreenState();
}

class _SafetySetupScreenState extends State<SafetySetupScreen> {
  final _db = DatabaseHelper();
  List<TrustedContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.phone,
    ].request();
  }

  Future<void> _loadContacts() async {
    final contacts = await _db.getTrustedContacts();
    if (mounted) setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _addContact() async {
    if (_contacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 trusted contacts allowed')),
      );
      return;
    }
    final contact = await _showContactDialog(null);
    if (contact != null) {
      await _db.saveTrustedContact(contact.copyWith(priority: _contacts.length + 1));
      await _loadContacts();
    }
  }

  Future<void> _editContact(TrustedContact contact) async {
    final updated = await _showContactDialog(contact);
    if (updated != null) {
      await _db.saveTrustedContact(updated);
      await _loadContacts();
    }
  }

  Future<void> _deleteContact(TrustedContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${contact.name}?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: AppColors.tertiary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true && contact.id != null) {
      await _db.deleteTrustedContact(contact.id!);
      await _loadContacts();
    }
  }

  Future<TrustedContact?> _showContactDialog(TrustedContact? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final relationCtrl = TextEditingController(text: existing?.relation ?? '');

    return showDialog<TrustedContact>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          existing == null ? 'Add Trusted Contact' : 'Edit Contact',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(controller: nameCtrl, hint: 'Full name', label: 'Name'),
            const SizedBox(height: 12),
            _Field(
              controller: phoneCtrl,
              hint: '+91 98765 43210',
              label: 'Phone',
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _Field(controller: relationCtrl, hint: 'Mother, Friend, etc.', label: 'Relation'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                TrustedContact(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  relation: relationCtrl.text.trim(),
                  priority: existing?.priority ?? 1,
                ),
              );
            },
            child: Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Trusted Contacts', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D2D).withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFF2D2D).withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'These people will be called & texted in an emergency.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF2D2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'They receive your live location and a voice call immediately. Add the most trusted people — family, close friends.',
                        style: TextStyle(fontSize: 11, color: const Color(0xFFFF2D2D).withAlpha(180), height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Contact list
                ..._contacts.asMap().entries.map((e) {
                  final contact = e.value;
                  const labels = ['1st', '2nd', '3rd'];
                  final priorityLabel = e.key < labels.length ? labels[e.key] : '${e.key + 1}th';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              contact.name[0].toUpperCase(),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(contact.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(priorityLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  ),
                                ],
                              ),
                              Text(contact.phone, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              if (contact.relation.isNotEmpty)
                                Text(contact.relation, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 18),
                              onPressed: () => _editContact(contact),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.tertiary, size: 18),
                              onPressed: () => _deleteContact(contact),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                // Add button
                if (_contacts.length < 3)
                  GestureDetector(
                    onTap: _addContact,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withAlpha(60), style: BorderStyle.solid),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Add Trusted Contact', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Tip: Add contacts who are always reachable and will act fast. A family member and a close friend is the ideal combination.',
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final TextInputType keyboard;

  const _Field({
    required this.controller,
    required this.hint,
    required this.label,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
