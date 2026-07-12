/// Запис АСВП (одне виконавче провадження проти боржника).
class Debtor {
  final String name;
  final String birthdate;
  final String code;         // ІПН / ЄДРПОУ (для фізосіб зазвичай порожній)
  final String creditorName; // стягувач
  final String vpNum;        // № виконавчого провадження
  final String vpBeginDate;  // дата відкриття
  final String vpState;      // статус (Завершено / відкрито)
  final String orgName;      // орган ДВС / виконавець

  Debtor({
    required this.name,
    required this.birthdate,
    required this.code,
    required this.creditorName,
    required this.vpNum,
    required this.vpBeginDate,
    required this.vpState,
    required this.orgName,
  });

  factory Debtor.fromJson(Map<String, dynamic> j) => Debtor(
        name: j['debtor_name'] as String? ?? '',
        birthdate: j['birthdate'] as String? ?? '',
        code: j['code'] as String? ?? '',
        creditorName: j['creditor_name'] as String? ?? '',
        vpNum: j['vp_num'] as String? ?? '',
        vpBeginDate: j['vp_begindate'] as String? ?? '',
        vpState: j['vp_state'] as String? ?? '',
        orgName: j['org_name'] as String? ?? '',
      );

  /// Чи провадження завершене (для кольору статусу).
  bool get isClosed => vpState.toLowerCase().contains('заверш');
}
