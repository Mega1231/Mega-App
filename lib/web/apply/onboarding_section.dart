import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/caregiver_application.dart';
import '../../services/application_service.dart';
import '../../services/download/file_download.dart';
import '../../theme/app_theme.dart';
import '../../widgets/signature_pad.dart';
import 'letter_body.dart';

/// Stage 2 on the applicant's page: the five letters to read and sign.
class OnboardingSection extends StatelessWidget {
  final String token;
  final ApplicantApplication app;
  final ValueChanged<ApplicantApplication> onUpdated;

  const OnboardingSection({
    super.key,
    required this.token,
    required this.app,
    required this.onUpdated,
  });

  Future<void> _open(BuildContext context, OnboardingLetter letter) async {
    final updated = await Navigator.of(context).push<ApplicantApplication>(
      MaterialPageRoute(
        builder: (_) => _LetterPage(token: token, app: app, letter: letter),
      ),
    );
    if (updated != null) onUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final ob = app.onboarding!;
    final first = app.fullName.split(' ').first;
    final done = ob.status == OnboardingStatus.completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.successColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                done ? Icons.celebration : Icons.verified,
                color: AppTheme.successColor,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done
                          ? 'All done${first.isEmpty ? '' : ', $first'}!'
                          : 'Congratulations${first.isEmpty ? '' : ', $first'}!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      done
                          ? ob.loginCreated
                                ? 'You signed all your documents and your Mega Homecare app login is ready. Mega Homecare will send you your username and password.${ob.copiesEmailed ? ' A copy of each signed document was emailed to you.' : ''} You can download your copies below anytime.'
                                : 'You signed all your documents. Mega Homecare will send you your app login soon.${ob.copiesEmailed ? ' A copy of each signed document was emailed to you.' : ''} You can download your copies below anytime.'
                          : 'Your application was accepted. Please read and sign each of the 5 documents below. You sign once with your finger, and the date is added automatically.',
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E8EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Onboarding documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${ob.signedCount} of ${ob.letters.length} signed',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final l in ob.letters)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3E8EF)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        l.isSigned
                            ? Icons.check_circle
                            : Icons.description_outlined,
                        color: l.isSigned
                            ? AppTheme.successColor
                            : AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              l.isSigned
                                  ? 'Signed ${DateFormat('MMM d, h:mm a').format(l.signedAt!)}'
                                  : 'Not signed yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: l.isSigned
                                    ? AppTheme.successColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (l.isSigned) ...[
                        _DownloadButton(token: token, letter: l, compact: true),
                        TextButton(
                          onPressed: () => _open(context, l),
                          child: const Text('Read'),
                        ),
                      ] else
                        FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          onPressed: () => _open(context, l),
                          child: const Text('Sign'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LetterPage extends StatefulWidget {
  final String token;
  final ApplicantApplication app;
  final OnboardingLetter letter;

  const _LetterPage({
    required this.token,
    required this.app,
    required this.letter,
  });

  @override
  State<_LetterPage> createState() => _LetterPageState();
}

class _LetterPageState extends State<_LetterPage> {
  final _signature = SignatureController();
  bool _agree = false;
  bool _signing = false;
  late bool _drawNew = !widget.app.onboarding!.hasSignature;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppTheme.errorColor : AppTheme.textPrimary,
      ),
    );
  }

  Future<void> _sign() async {
    if (!_agree) {
      _toast(
        'Please tick the box to confirm you have read the document.',
        error: true,
      );
      return;
    }
    final png = _drawNew ? await _signature.toPng() : null;
    if (_drawNew && png == null) {
      _toast('Please sign in the box with your finger.', error: true);
      return;
    }
    setState(() => _signing = true);
    try {
      final updated = await ApplicationService().signLetter(
        widget.token,
        letterId: widget.letter.id,
        signaturePng: png,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
      final left =
          updated.onboarding?.letters.where((l) => !l.isSigned).length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            left == 0
                ? 'All documents signed — thank you!'
                : '${widget.letter.title} signed. $left left.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _signing = false);
        _toast(ApplicationService.errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text(letter.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE3E8EF)),
                    ),
                    child: LetterBody(letter: letter),
                  ),
                  const SizedBox(height: 16),
                  if (letter.isSigned)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'You signed this document on ${DateFormat('MMMM d, y \'at\' h:mm a').format(letter.signedAt!)}.',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DownloadButton(token: widget.token, letter: letter),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE3E8EF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign this document',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _agree,
                            onChanged: _signing
                                ? null
                                : (v) => setState(() => _agree = v == true),
                            title: const Text(
                              'I have read and understood this document, and I agree to it.',
                              style: TextStyle(fontSize: 14.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_drawNew)
                            SignaturePad(controller: _signature)
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Your signature from your first document will be added.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _signing
                                        ? null
                                        : () => setState(() => _drawNew = true),
                                    child: const Text('Sign again'),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            'Date: ${DateFormat('MMMM d, y').format(DateTime.now())} (added automatically)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _signing ? null : _sign,
                              child: _signing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign document',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Downloads the caregiver's own signed copy (a PDF) to their phone.
class _DownloadButton extends StatefulWidget {
  final String token;
  final OnboardingLetter letter;
  final bool compact;

  const _DownloadButton({
    required this.token,
    required this.letter,
    this.compact = false,
  });

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final file = await ApplicationService().downloadSignedDocument(
        widget.token,
        widget.letter.id,
      );
      await saveGeneratedFile(
        file.bytes,
        file.fileName,
        mimeType: file.contentType,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApplicationService.errorText(e)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.download, size: 20);
    if (widget.compact) {
      return IconButton(
        tooltip: 'Download my signed copy',
        onPressed: _busy ? null : _download,
        icon: icon,
      );
    }
    return OutlinedButton.icon(
      onPressed: _busy ? null : _download,
      icon: icon,
      label: const Text('Download my signed copy (PDF)'),
    );
  }
}
