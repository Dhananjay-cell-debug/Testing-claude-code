import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../main.dart';
import 'safety_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _nameController = TextEditingController();
  final _db = DatabaseHelper();

  bool _obscureKey = true;
  bool _trackLocation = true;
  bool _trackSteps = true;
  bool _trackApps = true;
  bool _darkMode = false;
  bool _hasUsageAccess = false;
  bool _hasLocationPermission = false;
  bool _hasActivityPermission = false;
  bool _hasNotificationPermission = false;
  int _todaySteps = 0;
  int _screenMins = 0;

  static const _nativeChannel = MethodChannel('com.dhananjay.lifelens/native');

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAllPermissions();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkAllPermissions() async {
    try {
      final usage = await _nativeChannel.invokeMethod<bool>('hasUsageAccessPermission') ?? false;
      final location = await Permission.location.isGranted;
      final activity = await Permission.activityRecognition.isGranted;
      final notification = await Permission.notification.isGranted;
      if (mounted) {
        setState(() {
          _hasUsageAccess = usage;
          _hasLocationPermission = location;
          _hasActivityPermission = activity;
          _hasNotificationPermission = notification;
        });
      }
    } catch (_) {}
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      await _nativeChannel.invokeMethod('openUsageAccessSettings');
      await Future.delayed(const Duration(seconds: 2));
      await _checkAllPermissions();
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('user_name')) {
      await prefs.setString('user_name', 'Dhananjay Chitmilla');
    }
    const buildApiKey = String.fromEnvironment('CLAUDE_API_KEY', defaultValue: '');
    if (!prefs.containsKey('claude_api_key') && buildApiKey.isNotEmpty) {
      await prefs.setString('claude_api_key', buildApiKey);
    }
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? 'Dhananjay Chitmilla';
      _apiKeyController.text = prefs.getString('claude_api_key') ?? '';
      _trackLocation = prefs.getBool('track_location') ?? true;
      _trackSteps = prefs.getBool('track_steps') ?? true;
      _trackApps = prefs.getBool('track_apps') ?? true;
      _todaySteps = prefs.getInt('today_steps') ?? 0;
      _screenMins = prefs.getInt('today_screen_minutes') ?? 0;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _saveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('claude_api_key', _apiKeyController.text.trim());
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setBool('track_location', _trackLocation);
    await prefs.setBool('track_steps', _trackSteps);
    await prefs.setBool('track_apps', _trackApps);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Saved'), backgroundColor: AppColors.scoreHigh),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All Data', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          'Permanently deletes all tracked data and summaries. Cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.tertiary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.cleanOldData(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared'), backgroundColor: AppColors.tertiary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.only(top: topPad + 8, bottom: 48),
        children: [
          _buildPageTitle(),
          _buildProfileSection(),
          _buildTodayStatus(),
          _buildPermissionsSection(),
          _buildTrackingSection(),
          _buildAppearanceSection(),
          _buildSafetySection(),
          _buildClaudeSection(),
          _buildDangerSection(),
        ],
      ),
    );
  }

  Widget _buildPageTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        'Settings',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withAlpha(80), width: 2),
            ),
            child: Center(
              child: Text(
                _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'D',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isNotEmpty ? _nameController.text : 'Dhananjay Chitmilla',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                Text('LifeLens Pro', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showEditNameDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final ctrl = TextEditingController(text: _nameController.text);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Your Name', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_name', ctrl.text.trim());
              setState(() => _nameController.text = ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatus() {
    final screenH = _screenMins ~/ 60;
    final screenM = _screenMins % 60;
    final screenStr = screenH > 0 ? '${screenH}h ${screenM}m' : '${screenM}m';
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY', style: AppTextStyles.label),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(label: 'Screen', value: screenStr, color: AppColors.secondary),
              const SizedBox(width: 10),
              _StatChip(label: 'Steps', value: '$_todaySteps', color: AppColors.scoreHigh),
              const SizedBox(width: 10),
              _StatChip(label: 'Service', value: 'Active', color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERMISSIONS', style: AppTextStyles.label),
          const SizedBox(height: 12),
          _PermRow(
            label: 'Usage Access',
            subtitle: 'Screen time & app tracking',
            granted: _hasUsageAccess,
            onGrant: _openUsageAccessSettings,
            critical: true,
          ),
          _PermRow(
            label: 'Location',
            subtitle: 'Place detection',
            granted: _hasLocationPermission,
            onGrant: () async {
              await Permission.location.request();
              await _checkAllPermissions();
            },
          ),
          _PermRow(
            label: 'Activity',
            subtitle: 'Step counting',
            granted: _hasActivityPermission,
            onGrant: () async {
              await Permission.activityRecognition.request();
              await _checkAllPermissions();
            },
          ),
          _PermRow(
            label: 'Notifications',
            subtitle: 'Background service alert',
            granted: _hasNotificationPermission,
            onGrant: () async {
              await Permission.notification.request();
              await _checkAllPermissions();
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRACKING', style: AppTextStyles.label),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'App Usage',
            subtitle: 'Records screen time per app',
            value: _trackApps,
            onChanged: (v) async {
              setState(() => _trackApps = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('track_apps', v);
            },
          ),
          _ToggleRow(
            label: 'Location',
            subtitle: 'Detects where you spend time',
            value: _trackLocation,
            onChanged: (v) async {
              setState(() => _trackLocation = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('track_location', v);
            },
          ),
          _ToggleRow(
            label: 'Step Counting',
            subtitle: 'Counts steps throughout the day',
            value: _trackSteps,
            onChanged: (v) async {
              setState(() => _trackSteps = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('track_steps', v);
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPEARANCE', style: AppTextStyles.label),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Dark Mode',
            subtitle: 'Switch to dark theme',
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
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetySection() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SAFETY', style: AppTextStyles.label),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D2D).withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Drishti', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFF2D2D))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetySetupScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D2D).withAlpha(15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF2D2D).withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFFFF2D2D), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Trusted Emergency Contacts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFF2D2D))),
                        Text('Add up to 3 people who get alerted in emergencies', style: TextStyle(fontSize: 11, color: const Color(0xFFFF2D2D).withAlpha(180))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF2D2D), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaudeSection() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('CLAUDE AI', style: AppTextStyles.label),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Sonnet 4.6', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'monospace'),
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
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 18),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Stored locally on device. Never sent to any server other than Anthropic.',
            style: AppTextStyles.body.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerSection() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DATA', style: AppTextStyles.label),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'All data is stored locally on your device.',
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _clearAllData,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.tertiary,
                side: BorderSide(color: AppColors.tertiary.withAlpha(120)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Clear All Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;

  const _Card({required this.child, required this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final String label, subtitle;
  final bool granted;
  final VoidCallback onGrant;
  final bool critical;
  final bool isLast;

  const _PermRow({
    required this.label,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
    this.critical = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = granted ? AppColors.scoreHigh : (critical ? AppColors.tertiary : AppColors.textMuted);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(
                granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (!granted)
                GestureDetector(
                  onTap: onGrant,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: critical ? AppColors.tertiary : AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Grant',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                )
              else
                Text('Granted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.scoreHigh)),
            ],
          ),
        ),
        if (!isLast) Divider(color: AppColors.border, height: 1),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: AppColors.border, height: 1),
      ],
    );
  }
}
