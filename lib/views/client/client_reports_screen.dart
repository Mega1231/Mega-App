import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/report_viewmodel.dart';
import '../common/report_list_widget.dart';

class ClientReportsScreen extends StatefulWidget {
  /// If provided, load reports for this client. Otherwise uses the current
  /// user's UID (i.e. the logged-in client themselves).
  final String? clientId;
  final String title;
  final bool showBackButton;
  final String emptyMessage;

  const ClientReportsScreen({
    super.key,
    this.clientId,
    this.title = 'Care Reports',
    this.showBackButton = false,
    this.emptyMessage =
        'No care reports yet.\nReports from your caregiver will appear here.',
  });

  @override
  State<ClientReportsScreen> createState() => _ClientReportsScreenState();
}

class _ClientReportsScreenState extends State<ClientReportsScreen> {
  late ReportViewModel _reportVm;
  late String _clientId;

  @override
  void initState() {
    super.initState();
    _reportVm = ReportViewModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      _clientId = widget.clientId ?? authVm.currentUser!.uid;
      _reportVm.loadClientReports(_clientId);
    });
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
        appBar: AppBar(
          title: Text(widget.title),
          automaticallyImplyLeading: widget.showBackButton,
        ),
        body: ReportListWidget(
          emptyMessage: widget.emptyMessage,
          onLoadMore: () => _reportVm.loadMoreClientReports(_clientId),
        ),
      ),
    );
  }
}
