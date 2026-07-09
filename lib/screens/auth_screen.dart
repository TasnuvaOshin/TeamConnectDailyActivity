import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _staffId = TextEditingController();
  final _password = TextEditingController();
  
  // Registration fields
  final _regUserId = TextEditingController();
  final _regName = TextEditingController();
  final _regPortfolio = TextEditingController();
  final _regSupId = TextEditingController();
  final _regPassword = TextEditingController();
  final _regConfirmPassword = TextEditingController();
  
  String? _selectedTeam = 'Marketing Team';
  String? _selectedDesignation;
  
  bool _isRegistering = false;
  bool _loading = false;

  final Map<String, List<String>> _designationsByTeam = const {
    'Marketing Team': [
      'Business Manager',
      'Sr. General Manager',
      'General Manager',
      'Marketing Manager/DGM',
      'Asst. Marketing Manager',
      'Sr. PM/Sr. BM',
      'PM/BM/NDM/Manager',
      'Deputy Manager',
      'APM/ABM/AMBM/Asst./ Sr. Data Scientist',
      'Sr.PE/Sr.PDE/Sr.BDE/Sr.BE/Sr.Ex/Data Scientist/Sr. Planning Executive/ Planning Executive',
      'PE/PDE/BDE/BE/MCE/ Executive',
      'Jr. Executive/ Office',
    ],
    'Service Team': [
      'Sr. GM',
      'GM',
      'DGM',
      'AGM',
      'Manager',
      'Deputy Manager',
      'Assistant Manager',
      'Sr. Exe/ Sr. PE/ Sr. BPE/Sr.SPE/Sr. MIE',
      'Executive/PE/SPE/ SCE/ SOE',
      'Jr. TE/ Jr. Exe/ LO/ TE',
    ],
    'Supply Chain Team': [
      'DGM, Supply Chain',
      'AGM, Supply Chain',
      'Manager- CSWMSC/SCP/I & L',
      'Deputy Manager -CSWM/SC/SCP/I & L',
      'Assistant Manager -CSWM/SC/SCP/I & L',
      'Sr. Executive - SC/CSWM/SWM/SCCE/I &L',
      'Executive- SC/CSWM/SWM/SCCE',
    ],
    'Credit Team': [
      'Sr. Manager, CM',
      'Manager, CM',
      'Dy. Manager, CM',
      'Asst. Manager, CM',
      'Sr. Executive, CM',
      'Executive, CM/Logistic',
    ],
  };

  Future<void> _signIn() async {
    if (_staffId.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(_staffId.text.trim(), _password.text);
          
      // Auto-register push key (update/notification.php)
      final session = ref.read(sessionControllerProvider);
      if (session != null && !session.isDemo) {
        try {
          await ref.read(apiServiceProvider).registerNotification(
                session.userId,
                'mock-fcm-token-${session.userId}',
              );
        } catch (_) {
          // Non-fatal background registration error
        }
      }
      // Router redirect takes over → /dashboard.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.destructive,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_regUserId.text.trim().isEmpty ||
        _regName.text.trim().isEmpty ||
        (_selectedDesignation == null || _selectedDesignation!.isEmpty) ||
        (_selectedTeam == null || _selectedTeam!.isEmpty) ||
        _regPortfolio.text.trim().isEmpty ||
        _regSupId.text.trim().isEmpty ||
        _regPassword.text.isEmpty ||
        _regConfirmPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all fields'),
        backgroundColor: AppColors.destructive,
      ));
      return;
    }
    if (_regPassword.text != _regConfirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Passwords do not match'),
        backgroundColor: AppColors.destructive,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiServiceProvider).register(
            staffId: _regUserId.text.trim(),
            name: _regName.text.trim(),
            designation: _selectedDesignation!,
            team: _selectedTeam!,
            portfolio: _regPortfolio.text.trim(),
            supId: _regSupId.text.trim(),
            password: _regPassword.text,
          );
      if (!res.ok) {
        throw Exception(res.data ?? 'Registration failed');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration successful! Please sign in.'),
          backgroundColor: AppColors.forest,
        ));
        setState(() {
          _isRegistering = false;
          _staffId.text = _regUserId.text.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.destructive,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.forestDeep,
              AppColors.forest,
              AppColors.forestSoft,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: wide ? 1000 : 440, minHeight: wide ? (_isRegistering ? 700 : 450) : 0),
              child: wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(child: _BrandPanel()),
                          const SizedBox(width: 28),
                          Expanded(child: _formCard()),
                        ],
                      ),
                    )
                  : _formCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _isRegistering ? _buildRegisterFields() : _buildLoginFields(),
        ),
      ),
    );
  }

  List<Widget> _buildLoginFields() {
    return [
      Text('Sign in', style: display(size: 24, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Use your credentials.',
          style: TextStyle(color: AppColors.mute, fontSize: 13)),
      const SizedBox(height: 22),
      const _FieldLabel('User ID'),
      TextField(
        controller: _staffId,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(hintText: 'e.g. 123456'),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('Password'),
      TextField(
        controller: _password,
        obscureText: true,
        onSubmitted: (_) => _signIn(),
        decoration: const InputDecoration(hintText: '••••••'),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _loading ? null : _signIn,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Sign in'),
      ),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _isRegistering = true),
          child: const Text("Don't have an account? Register"),
        ),
      ),
    ];
  }

  List<Widget> _buildRegisterFields() {
    final designationsList = _designationsByTeam[_selectedTeam] ?? [];
    return [
      Text('Register', style: display(size: 24, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Create your Team Connect account.',
          style: TextStyle(color: AppColors.mute, fontSize: 13)),
      const SizedBox(height: 16),
      
      const _FieldLabel('Employee-ID'),
      TextField(
        controller: _regUserId,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(hintText: 'e.g. 123456'),
      ),
      const SizedBox(height: 10),
      
      const _FieldLabel('Supervisor-ID'),
      TextField(
        controller: _regSupId,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(hintText: 'e.g. 12345'),
      ),
      const SizedBox(height: 10),
      
      const _FieldLabel('Your Name'),
      TextField(
        controller: _regName,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(hintText: 'e.g. Sifat Rahman'),
      ),
      const SizedBox(height: 10),
      
      const _FieldLabel('Select Team'),
      DropdownButtonFormField<String>(
        value: _selectedTeam,
        isExpanded: true,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        items: _designationsByTeam.keys
            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _selectedTeam = v;
            _selectedDesignation = null;
          });
        },
      ),
      const SizedBox(height: 10),
      
      const _FieldLabel('Your Designation'),
      DropdownButtonFormField<String>(
        value: _selectedDesignation,
        isExpanded: true,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        hint: const Text('Select Designation', style: TextStyle(fontSize: 13)),
        items: designationsList
            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) => setState(() => _selectedDesignation = v),
      ),
      const SizedBox(height: 10),
      
      const _FieldLabel('Portfolio Name'),
      TextField(
        controller: _regPortfolio,
        decoration: const InputDecoration(hintText: 'e.g. Tractor'),
      ),
      const SizedBox(height: 10),
      
      const _FieldLabel('Password'),
      TextField(
        controller: _regPassword,
        obscureText: true,
        decoration: const InputDecoration(hintText: '••••••'),
      ),
      const SizedBox(height: 10),
      
      const _FieldLabel('Confirm Password'),
      TextField(
        controller: _regConfirmPassword,
        obscureText: true,
        decoration: const InputDecoration(hintText: '••••••'),
      ),
      const SizedBox(height: 16),
      
      ElevatedButton(
        onPressed: _loading ? null : _register,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Register'),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _isRegistering = false),
          child: const Text('Already have an account? Sign in'),
        ),
      ),
    ];
  }
}

/// Left glass brand panel — desktop only (§1).
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Team Connect',
                    style: display(
                        size: 20,
                        weight: FontWeight.w800,
                        color: Colors.white)),
                Text('ACI MOTORS • MARKETING',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: Colors.white.withAlpha(179))),
              ],
            ),
          ]),
          const SizedBox(height: 32),
          RichText(
            text: TextSpan(
              style: display(
                  size: 30,
                  weight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25),
              children: const [
                TextSpan(text: 'Daily activity, tasks and performance '),
                TextSpan(
                  text: 'across all levels.',
                  style: TextStyle(color: AppColors.amber),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'One command center for the entire marketing chain.',
            style: TextStyle(
                color: Colors.white.withAlpha(204), fontSize: 14, height: 1.5),
          ),
          const Spacer(),
          Text('© ${DateTime.now().year} ACI Motors Ltd.',
              style: TextStyle(
                  color: Colors.white.withAlpha(153), fontSize: 11)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text)),
      );
}
