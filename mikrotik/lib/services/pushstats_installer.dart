import '../models/router_device.dart';
import 'routeros_client.dart';

/// Встановлює моніторинг PushStats на роутер через RouterOS API:
/// створює скрипт `mm-pushstats` і scheduler (кожні 5 хв), який надсилає
/// статистику POST-ом на наш сервер через /tool fetch.
class PushStatsInstaller {
  static const scriptName = 'mm-pushstats';

  /// Шаблон RouterOS-скрипта. Все обгорнуто в :do on-error, щоб відсутні
  /// пакети (wireless, hotspot…) не ламали пуш. Сумісний з ROS 6.39+/7.x.
  static const _template = r'''
# MikroTik Mobile PushStats v1
:local mmEnc do={
  :local out ""
  :local chars {" "="%20";"!"="%21";"\""="%22";"#"="%23";"\$"="%24";"%"="%25";"&"="%26";"'"="%27";"+"="%2B";","="%2C";"/"="%2F";":"="%3A";";"="%3B";"="="%3D";"?"="%3F";"@"="%40"}
  :for i from=0 to=([:len $1]-1) do={
    :local ch [:pick $1 $i]
    :local enc ($chars->$ch)
    :if (any $enc) do={ :set out ($out . $enc) } else={ :set out ($out . $ch) }
  }
  :return $out
}
:local d "token={{TOKEN}}&did={{DID}}&push_version=1"
:do { :set d ($d . "&identity=" . [$mmEnc [/system identity get name]]) } on-error={}
:do { :set d ($d . "&model=" . [$mmEnc [/system resource get board-name]]) } on-error={}
:do { :set d ($d . "&version=" . [$mmEnc [/system resource get version]]) } on-error={}
:do { :set d ($d . "&uptime=" . [/system resource get uptime]) } on-error={}
:do { :set d ($d . "&cpu_load=" . [/system resource get cpu-load]) } on-error={}
:do { :set d ($d . "&mem_free=" . [/system resource get free-memory] . "&mem_total=" . [/system resource get total-memory]) } on-error={}
:do { :set d ($d . "&hdd_free=" . [/system resource get free-hdd-space] . "&hdd_total=" . [/system resource get total-hdd-space]) } on-error={}
:do { :set d ($d . "&health=" . [$mmEnc [:tostr [/system health print as-value]]]) } on-error={}
:do { :set d ($d . "&dhcp_lease_count=" . [/ip dhcp-server lease print count-only]) } on-error={}
:do { :set d ($d . "&wireless_reg_count=" . [/interface wireless registration-table print count-only]) } on-error={}
:do { :set d ($d . "&capsman_reg_count=" . [/caps-man registration-table print count-only]) } on-error={}
:do { :set d ($d . "&ppp_active_count=" . [/ppp active print count-only]) } on-error={}
:do { :set d ($d . "&hotspot_active_count=" . [/ip hotspot active print count-only]) } on-error={}
:do { :set d ($d . "&fw_connection_count=" . [/ip firewall connection print count-only]) } on-error={}
:do { :set d ($d . "&user_active_count=" . [/user active print count-only]) } on-error={}
:do {
  /interface monitor-traffic aggregate once do={
    :set d ($d . "&agg_tx=" . $"tx-bits-per-second" . "&agg_rx=" . $"rx-bits-per-second")
  }
} on-error={}
/tool fetch url="{{URL}}" http-method=post http-header-field="Content-Type: application/x-www-form-urlencoded" http-data=$d keep-result=no
''';

  static String buildScript(
      {required String serverUrl,
      required String token,
      required String did}) {
    return _template
        .replaceAll('{{URL}}', '$serverUrl/push')
        .replaceAll('{{TOKEN}}', token)
        .replaceAll('{{DID}}', did);
  }

  /// Підключається до роутера, ставить скрипт + scheduler і запускає
  /// перший пуш. Кидає виняток із поясненням при помилці.
  static Future<void> install({
    required RouterDevice device,
    required String serverUrl,
    required String token,
    String intervalMinutes = '5',
  }) async {
    final client = RouterOSClient();
    try {
      await client.connect(device.host, device.effectivePort,
          useSsl: device.useSsl);
      await client.login(device.username, device.password);

      // Унікальний ідентифікатор роутера: серійник, якщо є, інакше host.
      var did = device.host;
      try {
        final rb = await client.talk(['/system/routerboard/print']);
        final serial = rb.isNotEmpty ? rb.first['serial-number'] : null;
        if (serial != null && serial.isNotEmpty) did = serial;
      } on Object {
        // CHR/x86 без routerboard — лишаємо host
      }

      // Прибрати стару версію скрипта/scheduler-а.
      for (final path in ['/system/script', '/system/scheduler']) {
        try {
          final items =
              await client.talk(['$path/print', '?name=$scriptName']);
          for (final item in items) {
            final id = item['.id'];
            if (id != null) {
              await client.talk(['$path/remove', '=.id=$id']);
            }
          }
        } on Object {
          // не критично
        }
      }

      final source =
          buildScript(serverUrl: serverUrl, token: token, did: did);
      await client.talk([
        '/system/script/add',
        '=name=$scriptName',
        '=policy=read,write,test,policy',
        '=source=$source',
      ]);
      await client.talk([
        '/system/scheduler/add',
        '=name=$scriptName',
        '=interval=${intervalMinutes}m',
        '=on-event=/system script run $scriptName',
      ]);

      // Перший пуш одразу, щоб роутер з'явився у списку.
      try {
        await client.talk(['/system/script/run', '=number=$scriptName']);
      } on Object {
        // якщо fetch впав (немає інтернету/сертифіката) — скрипт все одно
        // встановлений і працюватиме за розкладом
      }
    } finally {
      client.close();
    }
  }

  /// Видаляє моніторинг з роутера.
  static Future<void> uninstall(RouterDevice device) async {
    final client = RouterOSClient();
    try {
      await client.connect(device.host, device.effectivePort,
          useSsl: device.useSsl);
      await client.login(device.username, device.password);
      for (final path in ['/system/scheduler', '/system/script']) {
        final items =
            await client.talk(['$path/print', '?name=$scriptName']);
        for (final item in items) {
          final id = item['.id'];
          if (id != null) {
            await client.talk(['$path/remove', '=.id=$id']);
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
