import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../services/audio_player_service.dart';
import '../models/repeat_mode.dart';
import '../theme/app_theme.dart';
import 'action_sheet_base.dart';

/// Smart Control Center — advanced playback controls inspired by the way
/// listeners actually reach for quick toggles (repeat, shuffle, sleep timer,
/// speed, bass boost, volume booster, equalizer presets).
///
/// All toggles stay in sync with the live [AudioPlayerService] engine, and the
/// equalizer presets are persisted through [MediaProvider].
Future<void> showControlCenter(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => const _ControlCenterSheet(),
  );
}

class _ControlCenterSheet extends StatefulWidget {
  const _ControlCenterSheet();

  @override
  State<_ControlCenterSheet> createState() => _ControlCenterSheetState();
}

class _ControlCenterSheetState extends State<_ControlCenterSheet> {
  late final MediaProvider provider;
  late final AudioPlayerService audio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    provider = context.read<MediaProvider>();
    audio = provider.audio;
  }

  String get _repeatLabel {
    switch (audio.repeatMode) {
      case PlayerRepeatMode.one:
        return 'One';
      case PlayerRepeatMode.all:
        return 'All';
      default:
        return 'Off';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.82,
      minChildSize: 0.4,
      builder: (context, scrollController) => Column(
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Text('Control Center',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _toggleRow(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  value: audio.isShuffle,
                  onChanged: (_) {
                    audio.toggleShuffle();
                    setState(() {});
                  },
                ),
                _selectableRow(
                  icon: Icons.repeat_rounded,
                  label: 'Repeat',
                  value: _repeatLabel,
                  options: const ['Off', 'One', 'All'],
                  onSelect: (_) {
                    audio.cycleRepeatMode();
                    setState(() {});
                  },
                ),
                _toggleRow(
                  icon: Icons.volume_up_rounded,
                  label: 'Volume booster',
                  value: audio.volumeBooster,
                  onChanged: (v) {
                    provider.setVolumeBooster(v ?? false);
                    setState(() {});
                  },
                ),
                _toggleRow(
                  icon: Icons.speaker_rounded,
                  label: 'Bass boost',
                  value: audio.bassBoost,
                  onChanged: (v) {
                    provider.setBassBoost(v ?? false);
                    setState(() {});
                  },
                ),
                _selectableRow(
                  icon: Icons.speed_rounded,
                  label: 'Playback speed',
                  value: '${audio.speed.toStringAsFixed(2)}x',
                  options: ['0.75', '0.87', '1.00', '1.25', '1.50', '2.00'],
                  onSelect: (value) {
                    audio.setPlaybackSpeed(double.parse(value));
                    setState(() {});
                  },
                ),
                _selectableRow(
                  icon: Icons.equalizer_rounded,
                  label: 'Equalizer',
                  value: provider.eqPreset,
                  options: const [
                    'Flat', 'Pop', 'Rock', 'Bass', 'Classical', 'Jazz'
                  ],
                  onSelect: (value) {
                    provider.setEqPreset(value);
                    setState(() {});
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _sleepTimerRow(),
                ),
              ],
            ),
          ),
                ],
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
            ),
                        Switch.adaptive(
              value: value,
              activeThumbColor: AppTheme.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectableRow({
    required IconData icon,
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelect,
  }) {
    return InkWell(
            onTap: () => _showOptionSheet(label, value, options, onSelect),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
            ),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

    Future<void> _showOptionSheet(
    String label,
    String current,
    List<String> options,
    ValueChanged<String> onSelect,
  ) {
    final theme = Theme.of(context);
    return showModalBottomSheet(
      context: context,
      backgroundColor: theme.bottomSheetTheme.modalBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Choose $label',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
                        Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((opt) {
                  final selected = opt == current;
                  return ChoiceChip(
                    label: Text(opt,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                    selected: selected,
                    onSelected: (_) {
                      Navigator.pop(ctx);
                      onSelect(opt);
                    },
                    selectedColor: AppTheme.accent,
                    backgroundColor: AppTheme.surfaceRaised,
                    shape: const StadiumBorder(),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _sleepTimerRow() {
    final remaining = audio.sleepTimerRemaining;
    final label = remaining != null
        ? '${remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remaining.inSeconds.remainder(60).toString().padLeft(2, '0')} left'
        : 'Sleep timer';
    return Row(
      children: [
                 const Icon(Icons.timer_rounded,
            size: 20, color: AppTheme.textPrimary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
        ),
        const SizedBox(width: 8),
                Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Wrap(
            spacing: 6,
            children: [
              for (final m in [5, 10, 15, 30])
                _pill('$m min', () {
                  audio.setSleepTimer(m);
                  setState(() {});
                }),
              _pill('Off', () {
                audio.cancelSleepTimer();
                setState(() {});
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: AppTheme.glass(radius: 14),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
      ),
    );
  }
}
