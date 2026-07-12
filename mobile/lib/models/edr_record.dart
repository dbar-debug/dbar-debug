/// Запис Єдиного державного реєстру: ФОП або юрособа (за ПІБ/назвою/ЄДРПОУ).
class EdrRecord {
  final String kind;     // ФОП / ЮО
  final String name;     // ПІБ (ФОП) або найменування (ЮО)
  final String code;     // ЄДРПОУ (у ФОП порожній)
  final String stan;     // стан: зареєстровано / припинено …
  final String regDate;  // дата держреєстрації
  final String role;     // для ЮО: керівник / засновник (у ФОП порожній)
  final String orgName;  // назва юрособи (для рядків керівника/засновника)
  final String extra;    // управитель майна, фермерське господарство тощо

  EdrRecord({
    required this.kind,
    required this.name,
    required this.code,
    required this.stan,
    required this.regDate,
    required this.role,
    required this.orgName,
    required this.extra,
  });

  factory EdrRecord.fromJson(Map<String, dynamic> j) => EdrRecord(
        kind: j['kind'] as String? ?? '',
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        stan: j['stan'] as String? ?? '',
        regDate: j['reg_date'] as String? ?? '',
        role: j['role'] as String? ?? '',
        orgName: j['org_name'] as String? ?? '',
        extra: j['extra'] as String? ?? '',
      );

  /// Чи чинний запис (не припинено).
  bool get isActive => !stan.toLowerCase().contains('припинено');
}
