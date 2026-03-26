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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.item,
    required this.colorScheme,
  });

  final KpiItem item;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final accent = item.color ?? colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.14),
              child: Icon(item.icon, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(item.label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
