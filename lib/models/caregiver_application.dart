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

  const ApplicantApplication({
    required this.fullName,
    required this.email,
    required this.status,
    required this.details,
    required this.documents,
    required this.generalComment,
    required this.requiredDocuments,
    required this.problems,
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
  });

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
  });

  ApplicationDocument doc(String id) =>
      documents[id] ?? const ApplicationDocument();

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
    );
  }
}
