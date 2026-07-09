import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hierarchy.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../data/static_data.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _searchController = TextEditingController();
  int _currentPage = 0;
  static const int _pageSize = 10;
  List<Profile> _allEmployees = [];

  @override
  void initState() {
    super.initState();
    _allEmployees = loadAllEmployees();
    if (_allEmployees.isEmpty) {
      final profiles = ref.read(allProfilesProvider).valueOrNull ?? [];
      _allEmployees = profiles;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(myRolesProvider).valueOrNull ?? const [];
    if (!roles.contains('admin')) {
      return const Center(
        child: Text(
          'Admin access only.',
          style: TextStyle(color: AppColors.mute),
        ),
      );
    }

    if (_allEmployees.isEmpty) {
      _allEmployees = loadAllEmployees();
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = _allEmployees.where((p) {
      if (query.isEmpty) return true;
      return p.fullName.toLowerCase().contains(query) ||
          (p.employeeId != null &&
              p.employeeId!.toLowerCase().contains(query)) ||
          p.designation.toLowerCase().contains(query) ||
          (p.department != null && p.department!.toLowerCase().contains(query));
    }).toList();

    final totalCount = filtered.length;
    final totalPages = (totalCount / _pageSize).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalCount);

    final pageItems = totalCount > 0
        ? filtered.sublist(startIndex, endIndex)
        : <Profile>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              color: AppColors.destructive,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Admin',
              style: display(
                size: 24,
                weight: FontWeight.w800,
                color: AppColors.forestDeep,
              ),
            ),
          ],
        ),
        const Text(
          'Directory and role structure across the organisation.',
          style: TextStyle(fontSize: 12, color: AppColors.mute),
        ),
        const SizedBox(height: 16),
        // Employee directory (§9.2)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Employee directory',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Total: $totalCount employees',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, designation, team...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.mute,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _currentPage = 0;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _currentPage = 0;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 6,
                    columnSpacing: 24,
                    headingTextStyle: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mute,
                      fontWeight: FontWeight.w600,
                    ),
                    columns: const [
                      DataColumn(
                        label: SizedBox(
                          width: 70,
                          child: Text('Level'),
                        ),
                      ),
                      DataColumn(label: Text('Employee')),
                      DataColumn(label: Text('Designation')),
                      DataColumn(label: Text('Department')),
                      DataColumn(label: Text('Zone')),
                      DataColumn(label: Text('Email')),
                    ],
                    rows: [
                      for (final p in pageItems)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 70,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: levelColor(p.roleLevel),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'L${p.roleLevel}',
                                      style: mono(size: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    p.employeeId ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: mono(
                                      size: 10,
                                      color: AppColors.mute,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                p.designation,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                p.department ?? '—',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                p.zone ?? '—',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(p.email ?? '—', style: mono(size: 11)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (totalPages > 1) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${startIndex + 1} to $endIndex of $totalCount entries',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mute,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                            icon: const Icon(Icons.chevron_left, size: 18),
                            label: const Text('Prev'),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Page ${_currentPage + 1} of $totalPages',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _currentPage < totalPages - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                            icon: const Icon(Icons.chevron_right, size: 18),
                            label: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Role structure (§9.3)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Role structure',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All 17 levels, coloured along the navy → teal → green '
                  'hierarchy gradient. Levels 1–12 observe; 13–17 log field '
                  'activity.',
                  style: TextStyle(fontSize: 11, color: AppColors.mute),
                ),
                const SizedBox(height: 12),
                for (final e in designations.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text('L${e.key}', style: mono(size: 12)),
                        ),
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: levelColor(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e.key <= observerMaxLevel ? 'Observer' : 'Field',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: e.key <= observerMaxLevel
                                ? AppColors.forest
                                : AppColors.moss,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
