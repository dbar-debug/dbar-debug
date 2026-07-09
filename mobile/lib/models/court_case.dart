class CourtCase {
  final String caseNumber;
  final String courtName;
  final String date;
  final String subtitle; // "my_role" для кабінету, "document_type" для пошуку
  final String url;
  final String excerpt;
  final String status; // тільки для кабінету, порожньо для публічного пошуку

  CourtCase({
    required this.caseNumber,
    required this.courtName,
    required this.date,
    required this.subtitle,
    required this.url,
    this.excerpt = '',
    this.status = '',
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
    );
  }
}
