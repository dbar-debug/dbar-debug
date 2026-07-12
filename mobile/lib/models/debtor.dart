/// Запис про борг/виконавче провадження (ЄРБ або АСВП).
class Debtor {
  final String source;       // ЄРБ / АСВП
  final String name;
  final String birthdate;
  final String code;         // ІПН / ЄДРПОУ (для фізосіб зазвичай порожній)
  final String creditorName; // стягувач (АСВП)
  final String category;     // категорія стягнення (ЄРБ)
  final String vpNum;        // № виконавчого провадження
  final String vpBeginDate;  // дата відкриття (АСВП)
  final String vpState;      // статус (АСВП: Завершено / відкрито)
  final String orgName;      // орган ДВС
  final String executor;     // виконавець (ЄРБ)

  Debtor({
    required this.source,
    required this.name,
    required this.birthdate,
    required this.code,
    required this.creditorName,
    required this.category,
    required this.vpNum,
    required this.vpBeginDate,
    required this.vpState,
    required this.orgName,
    required this.executor,
  });

  factory Debtor.fromJson(Map<String, dynamic> j) => Debtor(
        source: j['source'] as String? ?? '',
        name: j['debtor_name'] as String? ?? '',
        birthdate: j['birthdate'] as String? ?? '',
        code: j['code'] as String? ?? '',
        creditorName: j['creditor_name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        vpNum: j['vp_num'] as String? ?? '',
        vpBeginDate: j['vp_begindate'] as String? ?? '',
        vpState: j['vp_state'] as String? ?? '',
        orgName: j['org_name'] as String? ?? '',
        executor: j['executor'] as String? ?? '',
      );

  bool get isClosed => vpState.toLowerCase().contains('заверш');
}
