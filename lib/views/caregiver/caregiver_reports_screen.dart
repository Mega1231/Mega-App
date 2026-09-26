import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/caregiver_home_viewmodel.dart';
import '../../viewmodels/report_viewmodel.dart';
import '../common/report_list_widget.dart';
import 'create_report_screen.dart';

class CaregiverReportsScreen extends StatefulWidget {
  const CaregiverReportsScreen({super.key});

  @override
  State<CaregiverReportsScreen> createState() => _CaregiverReportsScreenState();
}

class _CaregiverReportsScreenState extends State<CaregiverReportsScreen> {
  late ReportViewModel _reportVm;
  List<String> _clientIds = [];

  @override
  void initState() {
    super.initState();
    _reportVm = ReportViewModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }

  void _loadReports() {
    final caregiverVm = context.read<CaregiverHomeViewModel>();
    _clientIds = caregiverVm.assignments.map((a) => a.clientId).toSet().toList();
    if (_clientIds.isNotEmpty) {
      _reportVm.loadCaregiverClientReports(_clientIds);
    } else {
      // Fallback: load only this caregiver's reports
      final uid = context.read<AuthViewModel>().currentUser!.uid;
      _reportVm.loadCaregiverReports(uid);
    }
  }

  @override
  void dispose() {
    _reportVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _reportVm,
      child: Scaffold(
        appBar: AppBar(title: const Text('Shift Reports')),
        body: ReportListWidget(
          emptyMessage:
              'No shift reports yet.\nSubmit one after your next visit!',
          onLoadMore: () {
            if (_clientIds.isNotEmpty) {
              _reportVm.loadMoreCaregiverClientReports(_clientIds);
            } else {
              final uid = context.read<AuthViewModel>().currentUser!.uid;
              _reportVm.loadMoreCaregiverReports(uid);
            }
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'createReport',
          onPressed: () {
            showCreateReportSheet(
              context,
              context.read<CaregiverHomeViewModel>().assignments,
              onReportCreated: _loadReports,
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('New Report'),
        ),
      ),
    );
  }
}
