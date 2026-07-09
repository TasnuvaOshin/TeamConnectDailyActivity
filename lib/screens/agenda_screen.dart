import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

const List<Map<String, String>> _monthList = [
  {'name': 'January', 'digit': '01'},
  {'name': 'February', 'digit': '02'},
  {'name': 'March', 'digit': '03'},
  {'name': 'April', 'digit': '04'},
  {'name': 'May', 'digit': '05'},
  {'name': 'June', 'digit': '06'},
  {'name': 'July', 'digit': '07'},
  {'name': 'August', 'digit': '08'},
  {'name': 'September', 'digit': '09'},
  {'name': 'October', 'digit': '10'},
  {'name': 'November', 'digit': '11'},
  {'name': 'December', 'digit': '12'},
];

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final isApiSession = session != null && !session.isDemo;
    final agendasAsync = ref.watch(myAgendasProvider);
    final now = DateTime.now();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myAgendasProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly Agenda',
                          style: display(
                              size: 24,
                              weight: FontWeight.w800,
                              color: AppColors.forestDeep)),
                      Text(
                        DateFormat('MMMM yyyy').format(now),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.mute),
                      ),
                    ],
                  ),
                ),
                if (isApiSession)
                  ElevatedButton.icon(
                    onPressed: () => _openAddAgendaDialog(context, ref),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Agenda'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (!isApiSession)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                        'Agendas are only available for live server sessions.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: AppColors.mute)),
                  ),
                ),
              )
            else
              agendasAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Could not load agendas: $err',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.destructive)),
                  ),
                ),
                data: (agendas) {
                  if (agendas.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                size: 64,
                                color: AppColors.mute.withAlpha(80)),
                            const SizedBox(height: 16),
                            const Text('No monthly agendas submitted yet.',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.mute)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: agendas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final agenda = agendas[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.amber.withAlpha(40),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: display(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: AppColors.amber),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_month,
                                            size: 14,
                                            color: AppColors.forest),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatPeriod(
                                              agenda.month, agenda.year),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.forestDeep),
                                        ),
                                        const Spacer(),
                                        Text(agenda.date,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.mute)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      agenda.agenda,
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.5),
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
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatPeriod(String m, String y) {
    if (m.isEmpty || y.isEmpty) return 'Monthly Agenda';
    final intMonth = int.tryParse(m) ?? 1;
    final monthName = (intMonth >= 1 && intMonth <= 12)
        ? _monthList[intMonth - 1]['name']!
        : m;
    return '$monthName $y';
  }

  Future<void> _openAddAgendaDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddAgendaDialog(),
    );
  }
}

class _AddAgendaDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddAgendaDialog> createState() => _AddAgendaDialogState();
}

class _AddAgendaDialogState extends ConsumerState<_AddAgendaDialog> {
  final TextEditingController _primaryController = TextEditingController();
  final List<TextEditingController> _extraControllers = [];
  late String _selectedYear;
  Map<String, String> _selectedMonth = _monthList[0];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year.toString();
    _selectedMonth = _monthList[now.month - 1];
  }

  void _addField() {
    setState(() => _extraControllers.add(TextEditingController()));
  }

  void _removeField(int index) {
    setState(() {
      _extraControllers[index].dispose();
      _extraControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _primaryController.dispose();
    for (final c in _extraControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.forestDeep,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Monthly Agenda',
                      style: display(
                          size: 18,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Year / Month selectors
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedYear,
                            decoration:
                                const InputDecoration(labelText: 'Year'),
                            items: [
                              for (int y = 2024; y <= 2030; y++)
                                DropdownMenuItem(
                                    value: y.toString(),
                                    child: Text(y.toString())),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedYear = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedMonth['digit'],
                            decoration:
                                const InputDecoration(labelText: 'Month'),
                            items: _monthList
                                .map((m) => DropdownMenuItem(
                                    value: m['digit'],
                                    child: Text(m['name']!)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedMonth = _monthList.firstWhere(
                                    (m) => m['digit'] == v);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Primary agenda field
                    const Text('Agenda Details *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestDeep)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _primaryController,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Describe your agenda for the month...',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('(Avoid using any special characters)',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.destructive)),
                    const SizedBox(height: 12),
                    // Extra agenda fields
                    for (int i = 0; i < _extraControllers.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text('Additional Agenda ${i + 1}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.forestDeep)),
                          ),
                          TextButton(
                            onPressed: () => _removeField(i),
                            child: const Text('Remove',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.destructive)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _extraControllers[i],
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Additional agenda details...',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Add more button
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _addField,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add More'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.destructive)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        _primaryController.text.trim().isEmpty || _saving
                            ? null
                            : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Agenda'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final session = ref.read(sessionControllerProvider)!;
      String lat = '', lan = '';
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5));
        lat = pos.latitude.toString();
        lan = pos.longitude.toString();
      } catch (_) {}

      final monthDigit = _selectedMonth['digit'] ?? '01';
      final yearStr = _selectedYear;
      final monthStr = monthDigit;

      // Submit primary agenda
      final primaryText = _primaryController.text
          .replaceAll(RegExp(r"[,!&']"), '')
          .trim();
      final res = await ref.read(apiServiceProvider).addAgendaNew(
            userId: session.userId,
            agenda: primaryText,
            year: yearStr,
            month: monthStr,
            lat: lat,
            lan: lan,
          );
      if (!res.ok) throw Exception('Server rejected the agenda');

      // Submit additional agendas
      for (final c in _extraControllers) {
        final text = c.text.replaceAll(RegExp(r"[,!&']"), '').trim();
        if (text.isNotEmpty) {
          await ref.read(apiServiceProvider).addAgendaNew(
                userId: session.userId,
                agenda: text,
                year: yearStr,
                month: monthStr,
                lat: lat,
                lan: lan,
              );
        }
      }

      ref.invalidate(myAgendasProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agenda submitted successfully'),
          backgroundColor: AppColors.forest,
        ));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.destructive,
        ));
      }
    }
  }
}
