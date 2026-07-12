/// Запис Єдиного реєстру боржників (одне виконавче провадження).
class Debtor {
  final String name;
  final String birthdate;
  final String code;      // ІПН / ЄДРПОУ
  final String publisher;
  final String orgName;   // орган ДВС
  final String executor;  // виконавець
  final String vpNum;     // № виконавчого провадження
  final String category;  // категорія стягнення

  Debtor({
    required this.name,
    required this.birthdate,
    required this.code,
    required this.publisher,
    required this.orgName,
    required this.executor,
    required this.vpNum,
    required this.category,
  });

  factory Debtor.fromJson(Map<String, dynamic> j) => Debtor(
        name: j['debtor_name'] as String? ?? '',
        birthdate: j['birthdate'] as String? ?? '',
        code: j['code'] as String? ?? '',
        publisher: j['publisher'] as String? ?? '',
        orgName: j['org_name'] as String? ?? '',
        executor: j['executor'] as String? ?? '',
        vpNum: j['vp_num'] as String? ?? '',
        category: j['category'] as String? ?? '',
      );
}
