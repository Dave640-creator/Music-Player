import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A square/rounded artwork tile that uses an image when available and falls
/// back to a deterministic aurora gradient with a monogram.
class Artwork extends StatelessWidget {
  final String? imagePath;
  final String seed;
  final double size;
  final double radius;
  final String? subtitle;

  const Artwork({
    super.key,
    this.imagePath,
    required this.seed,
    this.size = 48,
    this.radius = 12,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: hasImage ? null : AppTheme.artworkGradient(seed),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(
              File(imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _monogram(seed),
            )
          : _monogram(seed),
    );
  }

  Widget _monogram(String seed) {
    final letter = seed.isNotEmpty ? seed[0].toUpperCase() : '♪';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (subtitle != null)
          Positioned(
            right: -size * 0.15,
            bottom: -size * 0.15,
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.55,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        Center(
          child: Text(
            letter,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// A section title with an optional trailing action, used by Discover and
/// Library pages.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppTheme.accent),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}

/// Compact inline stat used by Discover hero cards.
class StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const StatPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Empty-state panel with an illustration glyph.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.25),
                    AppTheme.accent.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Icon(icon, size: 40, color: AppTheme.accent),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Small circular icon button with soft accent fill.
class SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  const SoftIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: (color ?? AppTheme.accent).withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.48, color: color ?? AppTheme.accent),
        ),
      ),
    );
  }
}

/// A pill-shaped gradient action button.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool expanded;

  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.pillGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glassy chip used for filters.
class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
          gradient: selected
              ? AppTheme.pillGradient
              : AppTheme.glass(radius: 20).gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Horizontal list of glass chips for a filter row.
class FilterChipRow extends StatelessWidget {
  final List<(String, bool, VoidCallback)> items;
  final EdgeInsets padding;

  const FilterChipRow({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final (label, selected, onTap) in items) ...[
            GlassChip(label: label, selected: selected, onTap: onTap),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}


