import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.currentRoute,
    super.key,
  });

  final String currentRoute;

  void _navigate(BuildContext context, String routeName) {
    Navigator.pop(context);
    if (routeName == currentRoute) {
      return;
    }
    Navigator.pushReplacementNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: FittedBox(
              alignment: Alignment.topLeft,
              fit: BoxFit.scaleDown,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'CyberSentinel',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Threat Monitoring',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            key: const Key('sidebar-/'),
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: currentRoute == '/',
            onTap: () => _navigate(context, '/'),
          ),
          ListTile(
            key: const Key('sidebar-/alerts'),
            leading: const Icon(Icons.warning_amber_rounded),
            title: const Text('Alerts'),
            selected: currentRoute == '/alerts',
            onTap: () => _navigate(context, '/alerts'),
          ),
          ListTile(
            key: const Key('sidebar-/monitoring'),
            leading: const Icon(Icons.network_check),
            title: const Text('Monitoring'),
            selected: currentRoute == '/monitoring',
            onTap: () => _navigate(context, '/monitoring'),
          ),
          ListTile(
            key: const Key('sidebar-/reports'),
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Reports'),
            selected: currentRoute == '/reports',
            onTap: () => _navigate(context, '/reports'),
          ),
          ListTile(
            key: const Key('sidebar-/incidents'),
            leading: const Icon(Icons.gpp_maybe_outlined),
            title: const Text('Incidents'),
            selected: currentRoute == '/incidents',
            onTap: () => _navigate(context, '/incidents'),
          ),
          ListTile(
            key: const Key('sidebar-/terminal'),
            leading: const Icon(Icons.terminal_rounded),
            title: const Text('Terminal'),
            selected: currentRoute == '/terminal',
            onTap: () => _navigate(context, '/terminal'),
          ),
          ListTile(
            key: const Key('sidebar-/settings'),
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            selected: currentRoute == '/settings',
            onTap: () => _navigate(context, '/settings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
