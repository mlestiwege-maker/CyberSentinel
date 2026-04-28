import 'package:flutter/material.dart';

class KpiItem {
  const KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
}

class KpiStrip extends StatelessWidget {
  const KpiStrip({
    required this.items,
    super.key,
  });

  final List<KpiItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: _KpiCard(item: items[i], colorScheme: colorScheme)),
                if (i < items.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _KpiCard(item: items[i], colorScheme: colorScheme),
              if (i < items.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.item,
    required this.colorScheme,
  });

  final KpiItem item;
  final ColorScheme colorScheme;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _isHovered = false;

  int? _tryParseInt(String raw) => int.tryParse(raw.trim());

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colorScheme = widget.colorScheme;
    final accent = item.color ?? colorScheme.primary;
    final numericValue = _tryParseInt(item.value);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.015 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Card(
          elevation: _isHovered ? 4.4 : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -18,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: _isHovered ? 0.30 : 0.22),
                          accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: accent.withValues(alpha: 0.14),
                      radius: 22,
                      child: Icon(item.icon, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (numericValue != null)
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: numericValue.toDouble()),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              key: ValueKey('kpi-${item.label}-${item.value}'),
                              builder: (context, value, _) {
                                return Text(
                                  value.round().toString(),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                );
                              },
                            )
                          else
                            Text(
                              item.value,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
