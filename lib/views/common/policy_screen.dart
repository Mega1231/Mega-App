import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

const String kSupportEmail = 'barakatyemmie@gmail.com';

class PolicySection {
  final IconData icon;
  final String heading;
  final String body;

  const PolicySection({
    required this.icon,
    required this.heading,
    required this.body,
  });
}

/// Nicely formatted screen for legal documents (privacy policy, terms).
class PolicyScreen extends StatelessWidget {
  final String title;
  final String intro;
  final String lastUpdated;
  final List<PolicySection> sections;

  const PolicyScreen({
    super.key,
    required this.title,
    required this.intro,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Intro card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intro,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.update,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      'Last updated: $lastUpdated',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ...sections.map((s) => _SectionCard(section: s)),

          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Questions? Email $kSupportEmail',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final PolicySection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(section.icon,
                    size: 20, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.heading,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            section.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Privacy Policy ───────────────────────────

const String kPrivacyIntro =
    'Mega Homecare Inc connects clients, caregivers, and administrators for '
    'home care coordination. This policy explains what information we '
    'collect and how we use it.';

const List<PolicySection> kPrivacySections = [
  PolicySection(
    icon: Icons.badge_outlined,
    heading: 'Information We Collect',
    body:
        'Account information (name, username, phone, address, emergency contact, and profile photo) created by your care agency administrator.\n\n'
        'Messages and photos you send through the in-app chat, and care visit reports created by caregivers.\n\n'
        'A push notification token so we can deliver message and call notifications to your device.\n\n'
        'Audio and video calls are transmitted in real time and are never recorded or stored by the app.',
  ),
  PolicySection(
    icon: Icons.tune,
    heading: 'How We Use Your Information',
    body:
        'To connect clients with their assigned caregivers, deliver messages, calls, and notifications, and maintain care visit reports for coordination.\n\n'
        'We never sell your personal information or share it with third parties for advertising.',
  ),
  PolicySection(
    icon: Icons.lock_outline,
    heading: 'Data Storage & Security',
    body:
        'Your data is stored securely using Google Firebase (Firestore, Authentication, and Storage). Access is restricted to you, your assigned care team, and your care agency\'s administrators.',
  ),
  PolicySection(
    icon: Icons.videocam_outlined,
    heading: 'Camera, Microphone & Photos',
    body:
        'Camera and microphone access is used only for video and audio calls. Photo library access is used only when you choose to share an image in chat or set a profile photo.',
  ),
  PolicySection(
    icon: Icons.delete_outline,
    heading: 'Data Retention & Deletion',
    body:
        'Your account and data are retained while you receive services from your care agency. To request deletion, contact your administrator or email $kSupportEmail. Requests are processed within 30 days.',
  ),
  PolicySection(
    icon: Icons.child_care_outlined,
    heading: 'Children\'s Privacy',
    body:
        'This app is intended for adults receiving or providing home care services and is not directed at children under 13.',
  ),
  PolicySection(
    icon: Icons.campaign_outlined,
    heading: 'Changes to This Policy',
    body:
        'We may update this policy from time to time. Significant changes will be communicated through the app.',
  ),
];

// ─────────────────────────── Terms of Service ───────────────────────────

const String kTermsIntro =
    'By using the Mega Homecare Inc app, you agree to these terms. Please read '
    'them carefully.';

const List<PolicySection> kTermsSections = [
  PolicySection(
    icon: Icons.person_outline,
    heading: 'Accounts',
    body:
        'Accounts are created and managed by your care agency administrator. You are responsible for keeping your login credentials confidential. Contact your administrator if you believe your account has been compromised.',
  ),
  PolicySection(
    icon: Icons.verified_user_outlined,
    heading: 'Acceptable Use',
    body:
        'Use the app only for legitimate care coordination. Do not share offensive, unlawful, or harmful content, attempt to access other users\' data, or disrupt the service.',
  ),
  PolicySection(
    icon: Icons.medical_services_outlined,
    heading: 'Care Services',
    body:
        'The app is a communication and coordination tool — it does not provide medical advice. In an emergency, call your local emergency services immediately. Do not rely on the app.',
  ),
  PolicySection(
    icon: Icons.forum_outlined,
    heading: 'Content & Oversight',
    body:
        'Messages, photos, and reports you submit remain your responsibility. Administrators may review conversations between clients and caregivers for quality and safety purposes.',
  ),
  PolicySection(
    icon: Icons.cloud_outlined,
    heading: 'Availability',
    body:
        'We aim to keep the app available at all times but do not guarantee uninterrupted service.',
  ),
  PolicySection(
    icon: Icons.no_accounts_outlined,
    heading: 'Termination',
    body:
        'Your care agency may deactivate accounts at its discretion, for example when care services end.',
  ),
  PolicySection(
    icon: Icons.gavel_outlined,
    heading: 'Limitation of Liability',
    body:
        'To the maximum extent permitted by law, Mega Homecare Inc is not liable for indirect or consequential damages arising from use of the app.',
  ),
];
