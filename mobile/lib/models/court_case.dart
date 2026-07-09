class CaseParticipant {
  final String name;
  final String role;

  CaseParticipant({required this.name, required this.role});

  factory CaseParticipant.fromJson(Map<String, dynamic> json) {
    return CaseParticipant(
      name: json['name'] as String? ?? '—',
      role: json['role'] as String? ?? '—',
    );
  }
}

class CourtCase {
  final String caseNumber;
  final String courtName;
  final String date;
  final String subtitle; // "my_role" для кабінету, "document_type" для пошуку
  final String url;
  final String excerpt;
  final String status; // тільки для кабінету, порожньо для публічного пошуку
  final String judge; // тільки для кабінету
  final String createdAt;
  final String updatedAt;
  final String proceedingNumber;
  final List<CaseParticipant> members;
  final List<CaseParticipant> judges;

  CourtCase({
    required this.caseNumber,
    required this.courtName,
    required this.date,
    required this.subtitle,
    required this.url,
    this.excerpt = '',
    this.status = '',
    this.judge = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.proceedingNumber = '',
    this.members = const [],
    this.judges = const [],
  });

  factory CourtCase.fromSearchJson(Map<String, dynamic> json) {
    return CourtCase(
      caseNumber: json['case_number'] as String? ?? '—',
      courtName: json['court_name'] as String? ?? '—',
      date: json['date'] as String? ?? '—',
      subtitle: json['document_type'] as String? ?? '—',
      url: json['url'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
    );
  }

  factory CourtCase.fromCabinetJson(Map<String, dynamic> json) {
    return CourtCase(
      caseNumber: json['case_number'] as String? ?? '—',
      courtName: json['court_name'] as String? ?? '—',
      date: json['date'] as String? ?? '—',
      subtitle: json['my_role'] as String? ?? '—',
      url: json['url'] as String? ?? '',
      status: json['status'] as String? ?? '',
      judge: json['judge'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      proceedingNumber: json['proceeding_number'] as String? ?? '',
      members: (json['members'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(CaseParticipant.fromJson)
          .toList(),
      judges: (json['judges'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(CaseParticipant.fromJson)
          .toList(),
    );
  }
}
