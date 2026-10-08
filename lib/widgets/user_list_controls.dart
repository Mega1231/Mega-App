import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../viewmodels/manage_users_viewmodel.dart';

/// Search box plus Active / Total / Inactive boxes that double as filters,
/// shared by the admin Clients and Caregivers lists.
class UserListControls extends StatelessWidget {
  final ManageUsersViewModel vm;
  final String searchHint;

  const UserListControls({super.key, required this.vm, required this.searchHint});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: vm.setQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: searchHint,
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FilterBox(
                count: vm.activeCount,
                label: 'Active',
                color: AppTheme.successColor,
                selected: vm.filter == 'active',
                onTap: () => vm.setFilter('active'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FilterBox(
                count: vm.totalCount,
                label: 'All',
                color: AppTheme.textSecondary,
                selected: vm.filter == 'all',
                onTap: () => vm.setFilter('all'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FilterBox(
                count: vm.inactiveCount,
                label: 'Inactive',
                color: AppTheme.errorColor,
                selected: vm.filter == 'inactive',
                onTap: () => vm.setFilter('inactive'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterBox extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterBox({
    required this.count,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.15),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
