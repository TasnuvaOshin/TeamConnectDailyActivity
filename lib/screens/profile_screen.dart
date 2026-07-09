import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/session.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _designationController = TextEditingController();
  final _teamController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionControllerProvider);
      if (session != null) {
        _designationController.text = session.designation;
        _teamController.text = session.team;
        _portfolioController.text = session.portfolio;
      }
    });
  }

  Future<void> _updateProfile() async {
    final session = ref.read(sessionControllerProvider);
    if (session == null) return;

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a password to confirm updates'),
        backgroundColor: AppColors.destructive,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      if (!session.isDemo) {
        final res = await ref.read(apiServiceProvider).updateProfile(
              empId: session.empId,
              designation: _designationController.text.trim(),
              password: _passwordController.text,
              portfolio: _portfolioController.text.trim(),
              team: _teamController.text.trim(),
            );
        if (!res.ok) {
          throw Exception('Profile update rejected by server');
        }
      }

      // Update local session
      final updated = Session(
        userId: session.userId,
        empId: session.empId,
        name: session.name,
        designation: _designationController.text.trim(),
        location: session.location,
        team: _teamController.text.trim(),
        portfolio: _portfolioController.text.trim(),
        isDemo: session.isDemo,
      );

      await ref.read(sessionControllerProvider.notifier).updateSession(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.forest,
        ));
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.destructive,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Future<void> _registerPushToken() async {
  //   final session = ref.read(sessionControllerProvider);
  //   if (session == null) return;
  // 
  //   setState(() => _loading = true);
  //   try {
  //     final token = 'manual-token-${session.userId}-${DateTime.now().millisecondsSinceEpoch}';
  //     if (!session.isDemo) {
  //       final res = await ref.read(apiServiceProvider).registerNotification(session.userId, token);
  //       if (!res.ok) throw Exception('Server registration error');
  //     }
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //         content: Text('Notification key registered: $token'),
  //         backgroundColor: AppColors.forest,
  //       ));
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //         content: Text('Failed to register key: $e'),
  //         backgroundColor: AppColors.destructive,
  //       ));
  //     }
  //   } finally {
  //     if (mounted) setState(() => _loading = false);
  //   }
  // }
  // 
  // Future<void> _deleteAccount() async {
  //   final session = ref.read(sessionControllerProvider);
  //   if (session == null) return;
  // 
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text('Delete Account'),
  //       content: const Text(
  //         'Are you sure you want to permanently delete your account? '
  //         'This action cannot be undone.',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx, false),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(ctx, true),
  //           style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
  //           child: const Text('Delete Account'),
  //         ),
  //       ],
  //     ),
  //   );
  // 
  //   if (confirm != true) return;
  // 
  //   setState(() => _loading = true);
  //   try {
  //     if (!session.isDemo) {
  //       final res = await ref.read(apiServiceProvider).deleteAccount(session.userId, session.name);
  //       if (!res.ok) throw Exception('Server rejected account deletion');
  //     }
  //     await ref.read(sessionControllerProvider.notifier).logout();
  //     if (mounted) {
  //       context.go('/auth');
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //         content: Text('Account deleted successfully.'),
  //       ));
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //         content: Text('Deletion failed: $e'),
  //         backgroundColor: AppColors.destructive,
  //       ));
  //     }
  //   } finally {
  //     if (mounted) setState(() => _loading = false);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile')),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('My Profile Settings',
                  style: display(size: 24, weight: FontWeight.w800, color: AppColors.forestDeep)),
              const Text('Manage your account configuration, password, and settings.',
                  style: TextStyle(fontSize: 12, color: AppColors.mute)),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile Information', style: display(size: 16, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Employee ID: ${session.empId}', style: const TextStyle(fontSize: 13, color: AppColors.mute)),
                      Text('Full Name: ${session.name}', style: const TextStyle(fontSize: 13, color: AppColors.mute)),
                      if (session.isDemo)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Demo Offline Session', style: TextStyle(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 20),
                      const Text('Designation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _designationController,
                        decoration: const InputDecoration(hintText: 'e.g. Product Executive'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Team / Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _teamController,
                        decoration: const InputDecoration(hintText: 'e.g. Marketing Team'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Portfolio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _portfolioController,
                        decoration: const InputDecoration(hintText: 'e.g. Tractor'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Confirm Password to Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.destructive)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Enter your password'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _updateProfile,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Update Profile'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Card(
              //   child: Padding(
              //     padding: const EdgeInsets.all(20),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Text('System & Push Notifications', style: display(size: 16, weight: FontWeight.w700)),
              //         const SizedBox(height: 6),
              //         const Text(
              //           'Push notification tokens are registered dynamically on login. '
              //           'Use the option below to manually re-register notification key settings.',
              //           style: TextStyle(fontSize: 12, color: AppColors.mute, height: 1.4),
              //         ),
              //         const SizedBox(height: 16),
              //         OutlinedButton.icon(
              //           onPressed: _loading ? null : _registerPushToken,
              //           icon: const Icon(Icons.notifications_active, size: 16),
              //           label: const Text('Register Notification Key'),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 20),
              // Card(
              //   color: Colors.red.shade50.withAlpha(200),
              //   child: Padding(
              //     padding: const EdgeInsets.all(20),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         const Text('Danger Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              //         const SizedBox(height: 6),
              //         const Text(
              //           'Once you delete your account, there is no going back. '
              //           'Please be certain.',
              //           style: TextStyle(fontSize: 12, color: AppColors.mute, height: 1.4),
              //         ),
              //         const SizedBox(height: 16),
              //         ElevatedButton.icon(
              //           style: ElevatedButton.styleFrom(
              //             backgroundColor: AppColors.destructive,
              //           ),
              //           onPressed: _loading ? null : _deleteAccount,
              //           icon: const Icon(Icons.delete_forever, size: 16, color: Colors.white),
              //           label: const Text('Delete Account', style: TextStyle(color: Colors.white)),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
