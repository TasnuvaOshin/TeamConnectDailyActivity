import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../hierarchy.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import 'level_avatar.dart';

class NavEntry {
  final String path;
  final String label;
  final IconData icon;
  const NavEntry(this.path, this.label, this.icon);
}

/// Nav logic per §10:
/// Observer (L1–12): Home / Team / Assign / Reports / Growth / [Admin]
/// Field (L13–17):  Home / Activity / Tasks / Growth / [Team]* / [Reports]* / [Admin]
/// *Team/Reports only when user has `manager` or `admin` role.
List<NavEntry> buildNav({
  required bool observer,
  required List<String> roles,
  required bool isApiSession,
}) {
  final isAdmin = roles.contains('admin');
  final isManager = roles.contains('manager') || isAdmin;
  if (observer) {
    return [
      const NavEntry('/dashboard', 'Home', Icons.space_dashboard_outlined),
      const NavEntry('/team', 'My Employee', Icons.groups_2_outlined),
      const NavEntry('/tasks', 'Tasks', Icons.checklist_rtl),
      const NavEntry('/agenda', 'Agenda', Icons.calendar_month_outlined),
      const NavEntry('/reports', 'Ratings', Icons.bar_chart_outlined),

      if (isApiSession)
        const NavEntry('/tour-plan', 'Tour Plan', Icons.map_outlined),
      // const NavEntry('/growth', 'Growth', Icons.trending_up),
      const NavEntry('/profile', 'Profile', Icons.person_outline),
      if (isAdmin) const NavEntry('/admin', 'Admin', Icons.shield_outlined),
    ];
  }
  return [
    const NavEntry('/dashboard', 'Home', Icons.space_dashboard_outlined),
    // const NavEntry('/activities', 'Activity', Icons.schedule_outlined),
    const NavEntry('/tasks', 'Tasks', Icons.checklist_rtl),
    const NavEntry('/agenda', 'Agenda', Icons.calendar_month_outlined),
    if (isApiSession)
      const NavEntry('/tour-plan', 'Tour Plan', Icons.map_outlined),
    const NavEntry('/growth', 'Growth', Icons.trending_up),
    const NavEntry('/profile', 'Profile', Icons.person_outline),
    if (isManager) const NavEntry('/team', 'Team', Icons.groups_2_outlined),
    if (isManager)
      const NavEntry('/reports', 'Reports', Icons.bar_chart_outlined),
    if (roles.contains('admin'))
      const NavEntry('/admin', 'Admin', Icons.shield_outlined),
  ];
}

/// 1 px forest→moss→lime brand ribbon (§0.7).
class BrandRibbon extends StatelessWidget {
  const BrandRibbon({super.key});
  @override
  Widget build(BuildContext context) => Container(
    height: 2,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.forestDeep, AppColors.moss, AppColors.lime],
      ),
    ),
  );
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final roles = ref.watch(myRolesProvider).valueOrNull ?? const [];
    final observer = isObserver(profile?.roleLevel);
    final session = ref.watch(sessionControllerProvider);
    final isApiSession = session != null && !session.isDemo;
    final nav = buildNav(
      observer: observer,
      roles: roles,
      isApiSession: isApiSession,
    );

    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(nav: nav, profile: profile),
            Expanded(
              child: Column(
                children: [
                  const BrandRibbon(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: top bar + first-5 bottom nav + "more" sheet for the rest.
    final bottom = nav.take(5).toList();
    final overflow = nav.skip(5).toList();
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset('lib/assets/alogo.png'),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Daily Activity'),
                Text(
                  'ACI MOTORS · MARKETING',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withAlpha(179),
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context, ref),
          ),
          if (overflow.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () =>
                  _openMoreSheet(context, ref, overflow, profile, location),
            ),
        ],
      ),
      body: Column(
        children: [
          const BrandRibbon(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _MobileBottomNav(
        entries: bottom,
        location: location,
      ),
    );
  }

  static Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionControllerProvider.notifier).logout();
    if (context.mounted) context.go('/auth');
  }

  void _openMoreSheet(
    BuildContext context,
    WidgetRef ref,
    List<NavEntry> entries,
    Profile? profile,
    String location,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'More',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.forestDeep,
          child: SafeArea(
            child: SizedBox(
              width: 260,
              height: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'MORE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final e in entries)
                    ListTile(
                      leading: Icon(e.icon, color: Colors.white70, size: 20),
                      title: Text(
                        e.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      selected: location.startsWith(e.path),
                      selectedTileColor: AppColors.sidebarAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go(e.path);
                      },
                    ),
                  const Spacer(),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.white70,
                      size: 20,
                    ),
                    title: const Text(
                      'Sign out',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _signOut(context, ref);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }
}

/// Bottom nav — 5 tabs, white on forest bar with safe-area padding (§0.7).
class _MobileBottomNav extends StatelessWidget {
  final List<NavEntry> entries;
  final String location;
  const _MobileBottomNav({required this.entries, required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.forestDeep,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final e in entries)
                Expanded(
                  child: InkWell(
                    onTap: () => context.go(e.path),
                    child: Builder(
                      builder: (_) {
                        final active =
                            location == e.path ||
                            location.startsWith('${e.path}/');
                        final color = active ? AppColors.lime : Colors.white70;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(e.icon, color: color, size: 21),
                            const SizedBox(height: 3),
                            Text(
                              e.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends ConsumerWidget {
  final List<NavEntry> nav;
  final Profile? profile;
  const _DesktopSidebar({required this.nav, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    return Container(
      width: 256, // w-64
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand block: Leaf on lime tile (§0.6 brand mark)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset('lib/assets/alogo.png'),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Team Connect',
                      style: display(
                        size: 15,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'ACI MOTORS · MARKETING',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              children: [
                for (final e in nav)
                  _SidebarLink(
                    entry: e,
                    active:
                        location == e.path || location.startsWith('${e.path}/'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          if (profile != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  LevelAvatar(profile: profile!, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile!.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'L${profile!.roleLevel} · ${profile!.designation}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => AppShell._signOut(context, ref),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  final NavEntry entry;
  final bool active;
  const _SidebarLink({required this.entry, required this.active});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.go(entry.path),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.sidebarAccent : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              entry.icon,
              color: active ? Colors.white : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (active)
              Container(
                width: 5,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
