import 'package:flutter/material.dart';

class Profile {
  final String id;
  final String fullName;
  final String? employeeId;
  final String? email;
  final int roleLevel;
  final String designation;
  final String? department;
  final String? zone;
  final String? managerId;
  final String? photoUrl;
  final String? phone;
  final bool isActive;

  Profile({
    required this.id,
    required this.fullName,
    required this.roleLevel,
    required this.designation,
    this.employeeId,
    this.email,
    this.department,
    this.zone,
    this.managerId,
    this.photoUrl,
    this.phone,
    this.isActive = true,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: (m['full_name'] ?? '') as String,
        employeeId: m['employee_id'] as String?,
        email: m['email'] as String?,
        roleLevel: (m['role_level'] ?? 17) as int,
        designation: (m['designation'] ?? '') as String,
        department: m['department'] as String?,
        zone: m['zone'] as String?,
        managerId: m['manager_id'] as String?,
        photoUrl: m['photo_url'] as String?,
        phone: m['phone'] as String?,
        isActive: m['is_active'] == true || m['is_active'] == 1 || m['is_active'] == null,
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
