import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class LibrarySetupScreen extends StatefulWidget {
  const LibrarySetupScreen({super.key});

  @override
  State<LibrarySetupScreen> createState() => _LibrarySetupScreenState();
}

class _LibrarySetupScreenState extends State<LibrarySetupScreen>
    with TickerProviderStateMixin {
  bool _isScanning = false;
  double _progress = 0.0;
  int _detected = 0;
  int _imported = 0;
  int _updated = 0;
  int _alreadyImported = 0;
  int _duplicates = 0;
  int _errors = 0;
  int _removed = 0;
  String? _error;
  bool _hasPermission = false;
  bool _permissionPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndScan();
  }

  Future<void> _checkPermissionAndScan() async {
    final scanner = context.read<MusicProvider>().scanner;
    final hasPerm = await scanner.hasPermission();
    if (!mounted) return;
    setState(() => _hasPermission = hasPerm);
    if (hasPerm) {
      _startScan();
    }
  }

  Future<void> _requestPermission() async {
    final scanner = context.read<MusicProvider>().scanner;
    final granted = await scanner.requestPermissions();
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      if (!granted) {
        _permissionPermanentlyDenied = true;
      }
    });
    if (granted) {
      _startScan();
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _progress = 0.0;
      _detected = 0;
      _imported = 0;
      _updated = 0;
      _alreadyImported = 0;
      _duplicates = 0;
      _errors = 0;
      _removed = 0;
      _error = null;
    });

    try {
      final provider = context.read<MusicProvider>();
      await provider.scanDevice(
        onProgress: (found, total) {
          if (!mounted) return;
          setState(() {
            _detected = found;
            _progress = total > 0 ? found / total : 0.0;
          });
        },
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _imported = result.imported;
            _updated = result.updated;
            _alreadyImported = result.alreadyImported;
            _duplicates = result.duplicates;
            _errors = result.errors;
            _removed = result.removed;
            _progress = 1.0;
            _isScanning = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
        _isScanning = false;
      });
    }
  }

  Future<void> _openSettings() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Permission Required'),
        content: const Text(
          'To import your music, please enable the Music permission in your device settings.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.library_music_rounded,
                    size: 50, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                _hasPermission && !_isScanning && _detected == 0
                    ? 'Your Library Is Ready'
                    : 'Build Your Music Library',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _hasPermission && !_isScanning && _detected == 0
                    ? 'No music files were found on your device.'
                    : 'Allow music access so the app can automatically find and organize your songs.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isScanning) ...[
                _ScanProgress(
                  progress: _progress,
                  detected: _detected,
                  imported: _imported,
                  updated: _updated,
                  alreadyImported: _alreadyImported,
                  duplicates: _duplicates,
                  errors: _errors,
                  removed: _removed,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Scanning...'),
                ),
              ] else if (_hasPermission &&
                  _detected > 0 &&
                  _progress >= 1.0) ...[
                _ScanResult(
                  imported: _imported,
                  updated: _updated,
                  alreadyImported: _alreadyImported,
                  duplicates: _duplicates,
                  errors: _errors,
                  removed: _removed,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const MainScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done'),
                ),
              ] else if (!_hasPermission && _permissionPermanentlyDenied) ...[
                OutlinedButton(
                  onPressed: _openSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Open System Settings'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _permissionPermanentlyDenied = false),
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    );
                  },
                  child: const Text('Skip for now'),
                ),
              ] else if (!_hasPermission) ...[
                ElevatedButton(
                  onPressed: _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Allow Music Access'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    );
                  },
                  child: const Text('Skip for now'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Scan Device'),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanProgress extends StatelessWidget {
  final double progress;
  final int detected;
  final int imported;
  final int updated;
  final int alreadyImported;
  final int duplicates;
  final int errors;
  final int removed;

  const _ScanProgress({
    required this.progress,
    required this.detected,
    required this.imported,
    required this.updated,
    required this.alreadyImported,
    required this.duplicates,
    required this.errors,
    required this.removed,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  detected > 0
                      ? 'Scanning... $pct%'
                      : 'Scanning device for music...',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
          if (detected > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppTheme.surfaceDark,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                minHeight: 6,
              ),
            ),
          ],
          if (detected > 0) ...[
            const SizedBox(height: 12),
            Text(
              '$detected detected  |  $imported new  |  $alreadyImported unchanged  |  $updated updated',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            if (duplicates > 0 || errors > 0 || removed > 0)
              Text(
                'Duplicates: $duplicates  |  Errors: $errors  |  Removed: $removed',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScanResult extends StatelessWidget {
  final int imported;
  final int updated;
  final int alreadyImported;
  final int duplicates;
  final int errors;
  final int removed;

  const _ScanResult({
    required this.imported,
    required this.updated,
    required this.alreadyImported,
    required this.duplicates,
    required this.errors,
    required this.removed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Library Updated',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (imported > 0)
            _row('New Songs', imported, AppTheme.accent),
          if (updated > 0)
            _row('Updated', updated, AppTheme.accentSecondary),
          if (alreadyImported > 0)
            _row('Already Imported', alreadyImported, AppTheme.textSecondary),
          if (duplicates > 0)
            _row('Duplicates Skipped', duplicates, AppTheme.accentTertiary),
          if (errors > 0)
            _row('Errors', errors, Colors.redAccent),
          if (removed > 0)
            _row('Removed Missing', removed, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _row(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
