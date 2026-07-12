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

/// Судове засідання з відкритих даних "Список справ призначених до розгляду".
class Hearing {
  final DateTime date; // день засідання
  final String time; // "10:30" або "" якщо невідомо
  final String caseNumber;
  final String courtName;
  final String judges;
  final String involved; // сторони
  final String description;
  final String room;

  Hearing({
    required this.date,
    required this.time,
    required this.caseNumber,
    required this.courtName,
    required this.judges,
    required this.involved,
    required this.description,
    required this.room,
  });

  factory Hearing.fromJson(Map<String, dynamic> json) {
    final raw = json['date'] as String? ?? '';
    final parsed = DateTime.tryParse(raw) ?? DateTime(1970);
    // час беремо або з окремого поля, або з datetime, якщо він там є
    var time = json['time'] as String? ?? '';
    if (time.isEmpty && (parsed.hour != 0 || parsed.minute != 0)) {
      time = '${parsed.hour.toString().padLeft(2, '0')}:'
          '${parsed.minute.toString().padLeft(2, '0')}';
    }
    return Hearing(
      date: DateTime(parsed.year, parsed.month, parsed.day),
      time: time,
      caseNumber: json['case_number'] as String? ?? json['case'] as String? ?? '—',
      courtName: json['court_name'] as String? ?? '—',
      judges: json['judges'] as String? ?? '—',
      involved: json['case_involved'] as String? ?? json['involved'] as String? ?? '',
      description: json['case_description'] as String? ?? json['description'] as String? ?? '',
      room: json['court_room'] as String? ?? json['room'] as String? ?? '',
    );
  }
}

class CaseDocument {
  final String number;
  final String date;
  final String description;
  final String docId;

  CaseDocument({
    required this.number,
    required this.date,
    required this.description,
    required this.docId,
  });

  factory CaseDocument.fromJson(Map<String, dynamic> json) {
    return CaseDocument(
      number: json['number'] as String? ?? '—',
      date: json['date'] as String? ?? '—',
      description: json['description'] as String? ?? '—',
      docId: json['doc_id'] as String? ?? '',
    );
  }
}

class CalendarEvent {
  final DateTime date;
  final String caseNumber;
  final String courtName;
  final String description;
  final String docId;
  final String caseId;

  CalendarEvent({
    required this.date,
    required this.caseNumber,
    required this.courtName,
    required this.description,
    required this.docId,
    required this.caseId,
  });

  /// Ознака, що подія — про призначене засідання/слухання.
  bool get isHearing {
    final d = description.toLowerCase();
    return d.contains('слухан') || d.contains('засідан') || d.contains('розгляд');
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final raw = json['date'] as String? ?? '';
    final parsed = DateTime.tryParse(raw) ?? DateTime(1970);
    return CalendarEvent(
      date: DateTime(parsed.year, parsed.month, parsed.day),
      caseNumber: json['case_number'] as String? ?? '—',
      courtName: json['court_name'] as String? ?? '—',
      description: json['description'] as String? ?? '—',
      docId: json['doc_id'] as String? ?? '',
      caseId: json['case_id'] as String? ?? '',
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
  final String caseId;
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
    this.caseId = '',
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
      caseId: json['case_id'] as String? ?? '',
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
