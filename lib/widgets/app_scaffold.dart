import 'package:flutter/material.dart';

import 'app_drawer.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.currentRoute,
    required this.title,
    required this.body,
    super.key,
  });

  final String currentRoute;
  final String title;
  final Widget body;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final TextEditingController _topSearchController = TextEditingController();

  static const List<_NavItem> _items = [
    _NavItem(route: '/', label: 'Dashboard', icon: Icons.dashboard_rounded),
    _NavItem(route: '/alerts', label: 'Alerts', icon: Icons.public_outlined),
    _NavItem(route: '/monitoring', label: 'Monitoring', icon: Icons.shield_outlined),
    _NavItem(route: '/reports', label: 'Reports', icon: Icons.bar_chart_rounded),
    _NavItem(route: '/incidents', label: 'Incidents', icon: Icons.error_outline),
    _NavItem(route: '/terminal', label: 'Terminal', icon: Icons.terminal_rounded),
    _NavItem(route: '/settings', label: 'Settings', icon: Icons.settings_rounded),
  ];

  @override
  void dispose() {
    _topSearchController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, String route) {
    if (route == widget.currentRoute) {
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  void _handleTopSearch(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) {
      return;
    }

    final route = switch (query) {
      String q when q.contains('alert') || q.contains('attack') || q.contains('map') => '/alerts',
      String q when q.contains('incident') => '/incidents',
      String q when q.contains('report') || q.contains('log') || q.contains('analytics') => '/reports',
      String q when q.contains('monitor') || q.contains('threat') || q.contains('status') => '/monitoring',
      String q when q.contains('terminal') || q.contains('command') || q.contains('console') => '/terminal',
      String q when q.contains('setting') || q.contains('role') || q.contains('user') || q.contains('twilio') || q.contains('sms') => '/settings',
      _ => null,
    };

    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No direct screen match for "$input". Try alerts, incidents, monitoring, reports, terminal, or settings.')),
      );
      return;
    }

    _topSearchController.clear();
    _navigate(context, route);
  }

  Widget _desktopSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const sidebarWidth = 270.0;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0C121E),
            const Color(0xFF0A0F19),
            colorScheme.surface.withValues(alpha: 0.96),
          ],
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1144C2),
                  const Color(0xFF1B8CFF).withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CyberSentinel',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'DEFENSIVE ATTACK TERMINAL',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF29D36A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SYSTEM SECURE',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                Text(
                  'MAIN NAVIGATION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ..._items.map((item) {
                  final selected = widget.currentRoute == item.route;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          gradient: selected
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFF1144C2).withValues(alpha: 0.90),
                                    const Color(0xFF1B8CFF).withValues(alpha: 0.82),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: selected ? null : Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: ListTile(
                          key: Key('sidebar-${item.route}'),
                          leading: Icon(
                            item.icon,
                            color: selected ? Colors.white : colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                          ),
                          title: Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: selected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.88),
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          dense: true,
                          onTap: () => _navigate(context, item.route),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF29D36A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CyberSentinel v2.0.0',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1200;

        if (!isDesktop) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            drawer: AppDrawer(currentRoute: widget.currentRoute),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(widget.currentRoute),
                child: widget.body,
              ),
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF09101A),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                _desktopSidebar(context),
                Expanded(
                  child: Column(
                    children: [
                      _DesktopTopBar(
                        title: widget.title,
                        searchController: _topSearchController,
                        onSearch: _handleTopSearch,
                        onNotificationsTap: () => _navigate(context, '/alerts'),
                        onThemeTap: () {
                          _navigate(context, '/settings');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Theme mode can be changed in Settings.')),
                          );
                        },
                        onProfileTap: () => _navigate(context, '/settings'),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: KeyedSubtree(
                            key: ValueKey(widget.currentRoute),
                            child: widget.body,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.searchController,
    required this.onSearch,
    required this.onNotificationsTap,
    required this.onThemeTap,
    required this.onProfileTap,
  });

  final String title;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onNotificationsTap;
  final VoidCallback onThemeTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B1120),
            const Color(0xFF0A0F19).withValues(alpha: 0.88),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: TextField(
                    controller: searchController,
                    onSubmitted: onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search threats, IPs, users, incidents...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        tooltip: 'Search',
                        onPressed: () => onSearch(searchController.text),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.65)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(
            color: const Color(0xFF29D36A),
            label: 'SYSTEM SECURE',
          ),
          const SizedBox(width: 14),
          _BadgeIcon(
            icon: Icons.notifications_none_rounded,
            badge: '12',
            onTap: onNotificationsTap,
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onThemeTap,
            tooltip: 'Theme settings',
            icon: const Icon(Icons.nightlight_round_rounded, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 14),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onProfileTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.85),
                    child: const Icon(Icons.person, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Admin',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'ADMIN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
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
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.badge, required this.onTap});

  final IconData icon;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
  });

  final String route;
  final String label;
  final IconData icon;
}
