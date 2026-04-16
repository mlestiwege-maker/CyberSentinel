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
  static bool _isSidebarCollapsed = false;

  static const List<_NavItem> _items = [
    _NavItem(route: '/', label: 'Dashboard', icon: Icons.dashboard),
    _NavItem(route: '/alerts', label: 'Alerts', icon: Icons.warning_amber_rounded),
    _NavItem(route: '/monitoring', label: 'Monitoring', icon: Icons.network_check),
    _NavItem(route: '/reports', label: 'Reports', icon: Icons.analytics_outlined),
    _NavItem(route: '/incidents', label: 'Incidents', icon: Icons.gpp_maybe_outlined),
    _NavItem(route: '/settings', label: 'Settings', icon: Icons.settings),
  ];

  void _navigate(BuildContext context, String route) {
    if (route == widget.currentRoute) {
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  Widget _desktopSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sidebarWidth = _isSidebarCollapsed ? 84.0 : 252.0;

    return Container(
      width: sidebarWidth,
      color: colorScheme.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security, color: Colors.white, size: 34),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(height: 8),
                  Text(
                    'CyberSentinel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SOC Command Center',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: _items
                  .map(
                    (item) => ListTile(
                      key: Key('sidebar-${item.route}'),
                      leading: Icon(item.icon),
                      title: _isSidebarCollapsed ? null : Text(item.label),
                      selected: widget.currentRoute == item.route,
                      onTap: () => _navigate(context, item.route),
                      minLeadingWidth: 0,
                      dense: _isSidebarCollapsed,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _isSidebarCollapsed ? 24 : 16,
                        vertical: _isSidebarCollapsed ? 4 : 2,
                      ),
                    ),
                  )
                  .toList(),
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
            body: widget.body,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                key: const Key('toggle-sidebar'),
                tooltip: _isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                icon: Icon(
                  _isSidebarCollapsed ? Icons.menu_open : Icons.menu,
                ),
                onPressed: () {
                  setState(() {
                    _isSidebarCollapsed = !_isSidebarCollapsed;
                  });
                },
              ),
            ],
          ),
          body: Row(
            children: [
              _desktopSidebar(context),
              const VerticalDivider(width: 1),
              Expanded(child: widget.body),
            ],
          ),
        );
      },
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
