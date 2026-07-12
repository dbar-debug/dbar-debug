/// Справа людини (обʼєднання стану + засідань за ПІБ) з /person/cases.
class PersonCase {
  final String caseNumber;
  final String courtName;
  final String judge;
  final String participants;
  final String description;
  final String stageName;
  final String stageDate;
  final List<HearingSlot> hearings;
  final HearingSlot? nextHearing;

  PersonCase({
    required this.caseNumber,
    required this.courtName,
    required this.judge,
    required this.participants,
    required this.description,
    required this.stageName,
    required this.stageDate,
    required this.hearings,
    required this.nextHearing,
  });

  factory PersonCase.fromJson(Map<String, dynamic> j) {
    final hearings = (j['hearings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(HearingSlot.fromJson)
        .toList();
    final nh = j['next_hearing'];
    return PersonCase(
      caseNumber: j['case_number'] as String? ?? '',
      courtName: j['court_name'] as String? ?? '',
      judge: j['judge'] as String? ?? '',
      participants: j['participants'] as String? ?? '',
      description: j['description'] as String? ?? '',
      stageName: j['stage_name'] as String? ?? '',
      stageDate: j['stage_date'] as String? ?? '',
      hearings: hearings,
      nextHearing: nh is Map<String, dynamic> ? HearingSlot.fromJson(nh) : null,
    );
  }
}

/// Одне засідання по справі (дата, час, зал).
class HearingSlot {
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final String room;

  HearingSlot({required this.date, required this.time, required this.room});

  factory HearingSlot.fromJson(Map<String, dynamic> j) => HearingSlot(
        date: j['date'] as String? ?? '',
        time: j['time'] as String? ?? '',
        room: j['court_room'] as String? ?? '',
      );

  /// '10.08.2026' з ISO-дати.
  String get dateHuman {
    final p = date.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : date;
  }
}

/// Рішення ЄДРСР по справі (з /decisions/by-case).
class Decision {
  final String docId;
  final String judgmentForm; // Рішення / Ухвала / Постанова
  final String justiceKind;  // Цивільне / Кримінальне ...
  final String category;
  final String adjudicationDate; // YYYY-MM-DD
  final String judge;
  final String reviewUrl; // HTML-сторінка тексту
  final String fileUrl;   // пряме .rtf
  final String status;

  Decision({
    required this.docId,
    required this.judgmentForm,
    required this.justiceKind,
    required this.category,
    required this.adjudicationDate,
    required this.judge,
    required this.reviewUrl,
    required this.fileUrl,
    required this.status,
  });

  factory Decision.fromJson(Map<String, dynamic> j) => Decision(
        docId: j['doc_id'] as String? ?? '',
        judgmentForm: j['judgment_form'] as String? ?? '',
        justiceKind: j['justice_kind'] as String? ?? '',
        category: j['category'] as String? ?? '',
        adjudicationDate: j['adjudication_date'] as String? ?? '',
        judge: j['judge'] as String? ?? '',
        reviewUrl: j['review_url'] as String? ?? '',
        fileUrl: j['file_url'] as String? ?? '',
        status: j['status'] as String? ?? '',
      );

  String get dateHuman {
    final p = adjudicationDate.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : adjudicationDate;
  }
}
