import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _db = DatabaseHelper();
  bool _obscureKey = true;
  bool _trackLocation = true;
  bool _trackSteps = true;
  bool _trackApps = true;
  int _dataRetentionDays = 30;
  String _lastLocation = '';
  int _todaySteps = 0;
  int _screenMins = 0;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Set defaults on first launch
    if (!prefs.containsKey('user_name')) {
      await prefs.setString('user_name', 'Dhananjay Chitmilla');
    }
    // Auto-populate API key injected at build time via --dart-define=CLAUDE_API_KEY=...
    const buildApiKey = String.fromEnvironment('CLAUDE_API_KEY', defaultValue: '');
    if (!prefs.containsKey('claude_api_key') && buildApiKey.isNotEmpty) {
      await prefs.setString('claude_api_key', buildApiKey);
    }
    setState(() {
      _apiKeyController.text = prefs.getString('claude_api_key') ?? '';
      _trackLocation = prefs.getBool('track_location') ?? true;
      _trackSteps = prefs.getBool('track_steps') ?? true;
      _trackApps = prefs.getBool('track_apps') ?? true;
      _dataRetentionDays = prefs.getInt('data_retention_days') ?? 30;
      _lastLocation = prefs.getString('last_location') ?? 'Not detected';
      _todaySteps = prefs.getInt('today_steps') ?? 0;
      _screenMins = prefs.getInt('today_screen_minutes') ?? 0;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('claude_api_key', _apiKeyController.text.trim());
    await prefs.setBool('track_location', _trackLocation);
    await prefs.setBool('track_steps', _trackSteps);
    await prefs.setBool('track_apps', _trackApps);
    await prefs.setInt('data_retention_days', _dataRetentionDays);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved!'),
          backgroundColor: AppColors.scoreHigh,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear All Data', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This will permanently delete all your tracked data and summaries. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything', style: TextStyle(color: AppColors.tertiary)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.cleanOldData(0); // Delete all
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared'), backgroundColor: AppColors.tertiary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        children: [
          _buildHeader(),
          _buildStatusSection(),
          _buildApiKeySection(),
          _buildAppearanceSection(),
          _buildTrackingSection(),
          _buildDataSection(),
          _buildAboutSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: AppSizes.padding,
        right: AppSizes.padding,
        bottom: 12,
      ),
      child: Text('SETTINGS', style: AppTextStyles.label.copyWith(color: AppColors.primary, fontSize: 14)),
    );
  }

  Widget _buildStatusSection() {
    return _Section(
      title: 'LIVE STATUS',
      children: [
        _StatusRow(emoji: '📍', label: 'Last Location', value: _lastLocation),
        _StatusRow(emoji: '👟', label: 'Today\'s Steps', value: '$_todaySteps'),
        _StatusRow(
          emoji: '📱',
          label: 'Screen Time',
          value: '${(_screenMins / 60).toStringAsFixed(1)}h',
        ),
        _StatusRow(
          emoji: '🔴',
          label: 'Background Service',
          value: 'Active',
          valueColor: AppColors.scoreHigh,
        ),
      ],
    );
  }

  Widget _buildApiKeySection() {
    return _Section(
      title: 'CLAUDE AI',
      children: [
        Text(
          'Your Claude API key is required to generate AI summaries. It\'s stored locally on your device only.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscureKey,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'sk-ant-api03-...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get your API key at console.anthropic.com',
          style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save API Key', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return _Section(
      title: 'APPEARANCE',
      children: [
        _ToggleRow(
          emoji: '🌙',
          label: 'Dark Mode',
          subtitle: 'Switch between light and dark theme',
          value: _darkMode,
          onChanged: (v) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('dark_mode', v);
            if (v) {
              AppColors.setDark();
            } else {
              AppColors.setLight();
            }
            // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
            themeNotifier.value = v;
            setState(() => _darkMode = v);
          },
        ),
      ],
    );
  }

  Widget _buildTrackingSection() {
    return _Section(
      title: 'TRACKING',
      children: [
        _ToggleRow(
          emoji: '📱',
          label: 'App Usage Tracking',
          subtitle: 'Requires Usage Access permission in Android settings',
          value: _trackApps,
          onChanged: (v) => setState(() => _trackApps = v),
        ),
        _ToggleRow(
          emoji: '📍',
          label: 'Location Tracking',
          subtitle: 'Detects where you spend your time',
          value: _trackLocation,
          onChanged: (v) => setState(() => _trackLocation = v),
        ),
        _ToggleRow(
          emoji: '👟',
          label: 'Step Counting',
          subtitle: 'Counts steps throughout the day',
          value: _trackSteps,
          onChanged: (v) => setState(() => _trackSteps = v),
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return _Section(
      title: 'DATA & PRIVACY',
      children: [
        Text(
          '⚠️ All your data is stored locally on your device. Nothing is sent to any server except Claude API calls for AI summaries.',
          style: AppTextStyles.body.copyWith(color: AppColors.scoreMid),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Keep data for:', style: AppTextStyles.body),
            const Spacer(),
            DropdownButton<int>(
              value: _dataRetentionDays,
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.textPrimary),
              items: [7, 14, 30, 60, 90].map((days) {
                return DropdownMenuItem(value: days, child: Text('$days days'));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _dataRetentionDays = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _clearAllData,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.tertiary,
              side: const BorderSide(color: AppColors.tertiary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear All Data', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _Section(
      title: 'ABOUT',
      children: [
        _InfoRow(label: 'App', value: 'LifeLens v1.0.0'),
        _InfoRow(label: 'Created by', value: 'Dhananjay Chitmilla'),
        _InfoRow(label: 'AI Model', value: 'Claude Sonnet 4.6'),
        _InfoRow(label: 'Data Storage', value: 'Local SQLite'),
        _InfoRow(label: 'Privacy', value: '100% On-device'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(title, style: AppTextStyles.label),
          ),
          Container(
            padding: const EdgeInsets.all(AppSizes.padding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String emoji, label, value;
  final Color? valueColor;

  const _StatusRow({
    required this.emoji,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String emoji, label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
                Text(subtitle, style: AppTextStyles.body.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(value, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
