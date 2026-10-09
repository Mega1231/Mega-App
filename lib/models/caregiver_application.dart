/// Caregiver application (onboarding stage 1). The record lives in the
/// server-only `applications` collection and reaches the app through the
/// application Cloud Functions, so timestamps arrive as epoch millis.
library;

DateTime? _date(dynamic v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String _str(dynamic v) => v is String ? v : '';

class RequiredDocument {
  final String id;
  final String label;
  final String hint;

  const RequiredDocument({
    required this.id,
    required this.label,
    required this.hint,
  });

  factory RequiredDocument.fromMap(Map<String, dynamic> m) => RequiredDocument(
    id: _str(m['id']),
    label: _str(m['label']),
    hint: _str(m['hint']),
  );
}

class ApplicationStatus {
  static const invited = 'invited';
  static const inProgress = 'in_progress';
  static const submitted = 'submitted';
  static const needsChanges = 'needs_changes';
  static const accepted = 'accepted';
  static const rejected = 'rejected';

  static const open = {invited, inProgress, needsChanges};

  static String label(String status) => switch (status) {
    invited => 'Link sent',
    inProgress => 'Filling in',
    submitted => 'Ready for review',
    needsChanges => 'Changes requested',
    accepted => 'Accepted',
    rejected => 'Rejected',
    _ => status,
  };
}

/// Per-document status: missing, uploaded, approved or needs_changes.
class DocStatus {
  static const missing = 'missing';
  static const uploaded = 'uploaded';
  static const approved = 'approved';
  static const needsChanges = 'needs_changes';
}

class Contact {
  final String name;
  final String relation;
  final String phone;
  final String email;

  const Contact({
    this.name = '',
    this.relation = '',
    this.phone = '',
    this.email = '',
  });

  factory Contact.fromMap(dynamic v) {
    final m = _map(v);
    return Contact(
      name: _str(m['name']),
      relation: _str(m['relation']),
      phone: _str(m['phone']),
      email: _str(m['email']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'relation': relation,
    'phone': phone,
    'email': email,
  };
}

class ApplicantDetails {
  final String fullName;
  final String email;
  final String phone;
  final Contact emergency;
  final List<Contact> references;

  const ApplicantDetails({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.emergency = const Contact(),
    this.references = const [Contact(), Contact()],
  });

  factory ApplicantDetails.fromMap(dynamic v) {
    final m = _map(v);
    final refs = m['references'] is List ? m['references'] as List : const [];
    return ApplicantDetails(
      fullName: _str(m['fullName']),
      email: _str(m['email']),
      phone: _str(m['phone']),
      emergency: Contact.fromMap(m['emergency']),
      references: [
        for (int i = 0; i < 2; i++)
          i < refs.length ? Contact.fromMap(refs[i]) : const Contact(),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'emergency': emergency.toMap(),
    'references': references.map((r) => r.toMap()).toList(),
  };
}

class DocumentVersion {
  final String fileName;
  final String storagePath;
  final String status;
  final String comment;
  final DateTime? uploadedAt;
  final DateTime? replacedAt;

  const DocumentVersion({
    required this.fileName,
    required this.storagePath,
    required this.status,
    required this.comment,
    this.uploadedAt,
    this.replacedAt,
  });

  factory DocumentVersion.fromMap(dynamic v) {
    final m = _map(v);
    return DocumentVersion(
      fileName: _str(m['fileName']),
      storagePath: _str(m['storagePath']),
      status: _str(m['status']),
      comment: _str(m['comment']),
      uploadedAt: _date(m['uploadedAt']),
      replacedAt: _date(m['replacedAt']),
    );
  }
}

class ApplicationDocument {
  final String status;
  final String fileName;
  final String contentType;
  final int size;
  final String comment;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;
  final String reviewedBy;
  final List<DocumentVersion> history;

  const ApplicationDocument({
    this.status = DocStatus.missing,
    this.fileName = '',
    this.contentType = '',
    this.size = 0,
    this.comment = '',
    this.uploadedAt,
    this.reviewedAt,
    this.reviewedBy = '',
    this.history = const [],
  });

  bool get hasFile => status != DocStatus.missing && fileName.isNotEmpty;

  factory ApplicationDocument.fromMap(dynamic v) {
    final m = _map(v);
    return ApplicationDocument(
      status: _str(m['status']).isEmpty ? DocStatus.missing : _str(m['status']),
      fileName: _str(m['fileName']),
      contentType: _str(m['contentType']),
      size: (m['size'] as num?)?.toInt() ?? 0,
      comment: _str(m['comment']),
      uploadedAt: _date(m['uploadedAt']),
      reviewedAt: _date(m['reviewedAt']),
      reviewedBy: _str(m['reviewedBy']),
      history: m['history'] is List
          ? (m['history'] as List).map(DocumentVersion.fromMap).toList()
          : const [],
    );
  }
}

class ActivityEntry {
  final String by;
  final String action;
  final String text;
  final DateTime? at;

  const ActivityEntry({
    required this.by,
    required this.action,
    required this.text,
    this.at,
  });

  factory ActivityEntry.fromMap(dynamic v) {
    final m = _map(v);
    return ActivityEntry(
      by: _str(m['by']),
      action: _str(m['action']),
      text: _str(m['text']),
      at: _date(m['at']),
    );
  }

  String get label => switch (action) {
    'created' => 'Application created',
    'submitted' => 'Submitted by applicant',
    'resubmitted' => 'Re-submitted by applicant',
    'approved' => 'Approved',
    'needs_changes' => 'Needs changes',
    'review_cleared' => 'Review cleared',
    'changes_requested' => 'Changes requested',
    'accepted' => 'Accepted',
    'rejected' => 'Rejected',
    'reopened' => 'Re-opened for review',
    'new_link' => 'New link created',
    'letters_sent' => 'Onboarding documents sent',
    'letters_updated' => 'Onboarding documents updated',
    'letters_signed' => 'All documents signed',
    'login_created' => 'App login created',
    _ => action,
  };
}

/// The applicant's own view of their application (from the link token).
class ApplicantApplication {
  final String fullName;
  final String email;
  final String status;
  final ApplicantDetails details;
  final Map<String, ApplicationDocument> documents;
  final String generalComment;
  final List<RequiredDocument> requiredDocuments;
  final List<String> problems;
  final ApplicantOnboarding? onboarding;

  const ApplicantApplication({
    required this.fullName,
    required this.email,
    required this.status,
    required this.details,
    required this.documents,
    required this.generalComment,
    required this.requiredDocuments,
    required this.problems,
    this.onboarding,
  });

  bool get isOpen => ApplicationStatus.open.contains(status);

  ApplicationDocument doc(String id) =>
      documents[id] ?? const ApplicationDocument();

  factory ApplicantApplication.fromMap(dynamic v) {
    final m = _map(v);
    return ApplicantApplication(
      fullName: _str(m['fullName']),
      email: _str(m['email']),
      status: _str(m['status']),
      details: ApplicantDetails.fromMap(m['details']),
      documents: _map(
        m['documents'],
      ).map((k, v) => MapEntry(k, ApplicationDocument.fromMap(v))),
      generalComment: _str(m['generalComment']),
      requiredDocuments: (m['requiredDocuments'] as List? ?? const [])
          .map((d) => RequiredDocument.fromMap(_map(d)))
          .toList(),
      problems: (m['problems'] as List? ?? const []).map(_str).toList(),
      onboarding: m['onboarding'] == null
          ? null
          : ApplicantOnboarding.fromMap(m['onboarding']),
    );
  }
}

/// One rendered piece of a letter (see functions/onboarding_letters.js):
/// h heading, p paragraph, pb bold paragraph, li bullet, kv label + value,
/// quote highlighted example, note centred emphasis, link.
class LetterBlock {
  final String type;
  final String text;
  final String label;
  final String value;

  const LetterBlock({
    required this.type,
    this.text = '',
    this.label = '',
    this.value = '',
  });

  factory LetterBlock.fromMap(dynamic v) {
    final m = _map(v);
    return LetterBlock(
      type: _str(m['t']),
      text: _str(m['text']),
      label: _str(m['label']),
      value: _str(m['value']),
    );
  }
}

class OnboardingLetter {
  final String id;
  final String title;
  final String heading;
  final List<LetterBlock> blocks;
  final DateTime? signedAt;

  const OnboardingLetter({
    required this.id,
    required this.title,
    this.heading = '',
    this.blocks = const [],
    this.signedAt,
  });

  bool get isSigned => signedAt != null;

  factory OnboardingLetter.fromMap(dynamic v) {
    final m = _map(v);
    return OnboardingLetter(
      id: _str(m['id']),
      title: _str(m['title']),
      heading: _str(m['heading']),
      blocks: (m['blocks'] as List? ?? const [])
          .map(LetterBlock.fromMap)
          .toList(),
      signedAt: _date(m['signedAt']),
    );
  }
}

class OnboardingStatus {
  static const notSent = 'not_sent';
  static const sent = 'sent';
  static const completed = 'completed';
}

/// The applicant's letters to read and sign.
class ApplicantOnboarding {
  final String status;
  final bool hasSignature;
  final bool loginCreated;
  final bool copiesEmailed;
  final List<OnboardingLetter> letters;

  const ApplicantOnboarding({
    required this.status,
    required this.hasSignature,
    required this.loginCreated,
    this.copiesEmailed = false,
    required this.letters,
  });

  int get signedCount => letters.where((l) => l.isSigned).length;

  factory ApplicantOnboarding.fromMap(dynamic v) {
    final m = _map(v);
    return ApplicantOnboarding(
      status: _str(m['status']),
      hasSignature: m['hasSignature'] == true,
      loginCreated: m['loginCreated'] == true,
      copiesEmailed: m['copiesEmailed'] == true,
      letters: (m['letters'] as List? ?? const [])
          .map(OnboardingLetter.fromMap)
          .toList(),
    );
  }
}

/// What Becky fills in when sending the letters.
class OnboardingFields {
  final String fullName;
  final String position;
  final String payRate;
  final String schedule;
  final String startDate;
  final String jobDescription;

  const OnboardingFields({
    required this.fullName,
    required this.position,
    required this.payRate,
    required this.schedule,
    required this.startDate,
    required this.jobDescription,
  });

  factory OnboardingFields.fromMap(dynamic v) {
    final m = _map(v);
    return OnboardingFields(
      fullName: _str(m['fullName']),
      position: _str(m['position']),
      payRate: _str(m['payRate']),
      schedule: _str(m['schedule']),
      startDate: _str(m['startDate']),
      jobDescription: _str(m['jobDescription']),
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'position': position,
    'payRate': payRate,
    'schedule': schedule,
    'startDate': startDate,
    'jobDescription': jobDescription,
  };
}

/// Onboarding as the admin sees it.
class AdminOnboarding {
  final String status;
  final OnboardingFields? fields;
  final DateTime? sentAt;
  final DateTime? completedAt;
  final List<OnboardingLetter> letters;
  final String caregiverUid;
  final String caregiverUsername;
  final String defaultPosition;
  final String defaultJobDescription;

  const AdminOnboarding({
    this.status = OnboardingStatus.notSent,
    this.fields,
    this.sentAt,
    this.completedAt,
    this.letters = const [],
    this.caregiverUid = '',
    this.caregiverUsername = '',
    this.defaultPosition = 'Caregiver',
    this.defaultJobDescription = '',
  });

  int get signedCount => letters.where((l) => l.isSigned).length;
  bool get loginCreated => caregiverUid.isNotEmpty;

  factory AdminOnboarding.fromMap(dynamic v) {
    final m = _map(v);
    final defaults = _map(m['defaults']);
    return AdminOnboarding(
      status: _str(m['status']).isEmpty
          ? OnboardingStatus.notSent
          : _str(m['status']),
      fields: m['fields'] == null
          ? null
          : OnboardingFields.fromMap(m['fields']),
      sentAt: _date(m['sentAt']),
      completedAt: _date(m['completedAt']),
      letters: (m['letters'] as List? ?? const [])
          .map(OnboardingLetter.fromMap)
          .toList(),
      caregiverUid: _str(m['caregiverUid']),
      caregiverUsername: _str(m['caregiverUsername']),
      defaultPosition: _str(defaults['position']).isEmpty
          ? 'Caregiver'
          : _str(defaults['position']),
      defaultJobDescription: _str(defaults['jobDescription']),
    );
  }
}

/// One row in the admin list.
class ApplicationSummary {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String status;
  final String link;
  final int uploaded;
  final int approved;
  final int needsChanges;
  final int total;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? lastApplicantActivityAt;
  final int reminderCount;
  final bool remindersOff;
  final String onboardingStatus;
  final int lettersSigned;
  final bool loginCreated;

  const ApplicationSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.status,
    required this.link,
    required this.uploaded,
    required this.approved,
    required this.needsChanges,
    required this.total,
    this.createdAt,
    this.submittedAt,
    this.lastApplicantActivityAt,
    required this.reminderCount,
    required this.remindersOff,
    this.onboardingStatus = OnboardingStatus.notSent,
    this.lettersSigned = 0,
    this.loginCreated = false,
  });

  /// Same as [ApplicationRecord.applicantHasWork].
  bool get applicantHasWork =>
      ApplicationStatus.open.contains(status) ||
      (status == ApplicationStatus.accepted &&
          onboardingStatus == OnboardingStatus.sent);

  factory ApplicationSummary.fromMap(dynamic v) {
    final m = _map(v);
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return ApplicationSummary(
      id: _str(m['id']),
      fullName: _str(m['fullName']),
      email: _str(m['email']),
      phone: _str(m['phone']),
      status: _str(m['status']),
      link: _str(m['link']),
      uploaded: n('uploaded'),
      approved: n('approved'),
      needsChanges: n('needsChanges'),
      total: n('total'),
      createdAt: _date(m['createdAt']),
      submittedAt: _date(m['submittedAt']),
      lastApplicantActivityAt: _date(m['lastApplicantActivityAt']),
      reminderCount: n('reminderCount'),
      remindersOff: m['remindersOff'] == true,
      onboardingStatus: _str(m['onboardingStatus']).isEmpty
          ? OnboardingStatus.notSent
          : _str(m['onboardingStatus']),
      lettersSigned: n('lettersSigned'),
      loginCreated: m['loginCreated'] == true,
    );
  }
}

/// Full record for the admin review screen.
class ApplicationRecord {
  final String id;
  final String fullName;
  final String email;
  final String status;
  final String link;
  final ApplicantDetails details;
  final Map<String, ApplicationDocument> documents;
  final String generalComment;
  final List<ActivityEntry> activity;
  final bool remindersOff;
  final int reminderCount;
  final DateTime? lastReminderAt;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? lastApplicantActivityAt;
  final List<String> problems;
  final List<RequiredDocument> requiredDocuments;
  final AdminOnboarding onboarding;

  const ApplicationRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.status,
    required this.link,
    required this.details,
    required this.documents,
    required this.generalComment,
    required this.activity,
    required this.remindersOff,
    required this.reminderCount,
    this.lastReminderAt,
    this.createdAt,
    this.submittedAt,
    this.lastApplicantActivityAt,
    required this.problems,
    required this.requiredDocuments,
    this.onboarding = const AdminOnboarding(),
  });

  ApplicationDocument doc(String id) =>
      documents[id] ?? const ApplicationDocument();

  /// The applicant still has something to do on their link (details,
  /// documents or signing letters), so sharing and reminders apply.
  bool get applicantHasWork =>
      ApplicationStatus.open.contains(status) ||
      (status == ApplicationStatus.accepted &&
          onboarding.status == OnboardingStatus.sent);

  bool get allApproved =>
      requiredDocuments.every((d) => doc(d.id).status == DocStatus.approved);

  /// The server only sends the document list on a full fetch; keep the last
  /// one when an action returns the record without it.
  factory ApplicationRecord.fromMap(
    dynamic v, {
    List<RequiredDocument> fallbackDocuments = const [],
  }) {
    final m = _map(v);
    final required =
        (m['requiredDocuments'] as List?)
            ?.map((d) => RequiredDocument.fromMap(_map(d)))
            .toList() ??
        fallbackDocuments;
    return ApplicationRecord(
      id: _str(m['id']),
      fullName: _str(m['fullName']),
      email: _str(m['email']),
      status: _str(m['status']),
      link: _str(m['link']),
      details: ApplicantDetails.fromMap(m['details']),
      documents: _map(
        m['documents'],
      ).map((k, v) => MapEntry(k, ApplicationDocument.fromMap(v))),
      generalComment: _str(m['generalComment']),
      activity: (m['activity'] as List? ?? const [])
          .map(ActivityEntry.fromMap)
          .toList(),
      remindersOff: m['remindersOff'] == true,
      reminderCount: (m['reminderCount'] as num?)?.toInt() ?? 0,
      lastReminderAt: _date(m['lastReminderAt']),
      createdAt: _date(m['createdAt']),
      submittedAt: _date(m['submittedAt']),
      lastApplicantActivityAt: _date(m['lastApplicantActivityAt']),
      problems: (m['problems'] as List? ?? const []).map(_str).toList(),
      requiredDocuments: required,
      onboarding: AdminOnboarding.fromMap(m['onboarding']),
    );
  }
}
