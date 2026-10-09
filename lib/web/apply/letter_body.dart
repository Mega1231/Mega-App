import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/caregiver_application.dart';
import '../../theme/app_theme.dart';

/// Renders an onboarding letter's blocks with the agency letterhead. Shared
/// by the applicant's signing page and the admin preview.
class LetterBody extends StatelessWidget {
  final OnboardingLetter letter;

  const LetterBody({super.key, required this.letter});

  static const _body = TextStyle(
    fontSize: 15,
    height: 1.55,
    color: AppTheme.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Mega Homecare Inc\n200 Glendale Avenue North, Hamilton ON L8L 7K3\ninfo@megahomecareinc.com · 888-811-3429',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/app_icon.jpg', width: 56, height: 56),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          letter.heading.isEmpty ? letter.title : letter.heading,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        for (final b in letter.blocks) _block(b),
      ],
    );
  }

  Widget _block(LetterBlock b) {
    switch (b.type) {
      case 'h':
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            b.text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        );
      case 'pb':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            b.text,
            style: _body.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      case 'kv':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${b.label} ',
                  style: _body.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: b.value.isEmpty ? '—' : b.value, style: _body),
              ],
            ),
          ),
        );
      case 'li':
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: _body),
              Expanded(child: Text(b.text, style: _body)),
            ],
          ),
        );
      case 'quote':
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            b.text,
            style: _body.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFFB3261E),
            ),
          ),
        );
      case 'note':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            b.text,
            textAlign: TextAlign.center,
            style: _body.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5B2A86),
            ),
          ),
        );
      case 'link':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () =>
                launchUrl(Uri.parse(b.text), webOnlyWindowName: '_blank'),
            child: Text(
              b.text,
              style: _body.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(b.text, style: _body),
        );
    }
  }
}
