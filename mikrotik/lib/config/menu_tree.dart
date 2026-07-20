import 'package:flutter/material.dart';

/// Опис поля у редакторі елемента.
class FieldSpec {
  final String key;
  final String label;
  final bool isToggle; // так/ні (yes/no)
  final String section;
  final String? hint;

  const FieldSpec(
    this.key,
    this.label, {
    this.isToggle = false,
    this.section = 'General',
    this.hint,
  });
}

/// Вузол дерева "Налаштування роутера".
abstract class MenuNode {
  final String title;
  final IconData icon;
  const MenuNode(this.title, this.icon);
}

/// Папка з підпунктами.
class MenuFolder extends MenuNode {
  final List<MenuNode> children;
  const MenuFolder(super.title, super.icon, this.children);
}

/// Таблиця RouterOS: шлях API, колонки для картки та поля редактора.
class MenuTable extends MenuNode {
  final String apiPath; // напр. '/ip/firewall/filter'
  final List<String> columns; // ключі, що показуються у списку
  final List<FieldSpec>? fields; // null — генеричний редактор за атрибутами
  final bool readOnly; // без add/set/remove (напр. connections, files)

  const MenuTable(
    super.title,
    super.icon,
    this.apiPath,
    this.columns, {
    this.fields,
    this.readOnly = false,
  });

  bool get canAdd => !readOnly && fields != null;
}

const List<FieldSpec> _commentDisable = [
  FieldSpec('comment', 'comment', section: 'Comment/Disable'),
  FieldSpec('disabled', 'disabled',
      isToggle: true, section: 'Comment/Disable'),
];

/// Поля правил firewall (filter / nat / mangle / raw) — як у Winbox.
List<FieldSpec> _firewallFields({required bool nat}) {
  return <FieldSpec>[
    ..._commentDisable,
    FieldSpec('chain', 'chain',
        hint: nat ? 'srcnat / dstnat' : 'input / forward / output'),
    const FieldSpec('src-address', 'src-address'),
    const FieldSpec('dst-address', 'dst-address'),
    const FieldSpec('protocol', 'protocol', hint: 'tcp / udp / icmp'),
    const FieldSpec('src-port', 'src-port'),
    const FieldSpec('dst-port', 'dst-port'),
    const FieldSpec('port', 'port'),
    const FieldSpec('in-interface', 'in-interface'),
    const FieldSpec('out-interface', 'out-interface'),
    const FieldSpec('packet-mark', 'packet-mark'),
    const FieldSpec('connection-state', 'connection-state',
        section: 'Advanced', hint: 'established,related'),
    const FieldSpec('connection-mark', 'connection-mark',
        section: 'Advanced'),
    const FieldSpec('src-address-list', 'src-address-list',
        section: 'Advanced'),
    const FieldSpec('dst-address-list', 'dst-address-list',
        section: 'Advanced'),
    FieldSpec('action', 'action',
        section: 'Action',
        hint: nat
            ? 'accept / masquerade / dst-nat / src-nat'
            : 'accept / drop / reject / jump / log'),
    if (nat) ...const [
      FieldSpec('to-addresses', 'to-addresses', section: 'Action'),
      FieldSpec('to-ports', 'to-ports', section: 'Action'),
    ] else
      const FieldSpec('jump-target', 'jump-target', section: 'Action'),
    const FieldSpec('log', 'log', isToggle: true, section: 'Action'),
    const FieldSpec('log-prefix', 'log-prefix', section: 'Action'),
  ];
}

/// Дерево "Налаштування роутера" — як у WinboxMobile (Router Settings).
final List<MenuNode> routerSettingsMenu = <MenuNode>[
  const MenuFolder('CAPsMAN', Icons.cast, [
    MenuTable('Interfaces', Icons.settings_input_antenna,
        '/caps-man/interface', ['name', 'mac-address', 'running']),
    MenuTable('Registration Table', Icons.list, '/caps-man/registration-table',
        ['interface', 'mac-address', 'uptime'],
        readOnly: true),
    MenuTable('Configurations', Icons.tune, '/caps-man/configuration',
        ['name', 'ssid']),
  ]),
  const MenuTable('Interfaces', Icons.settings_ethernet, '/interface',
      ['name', 'type', 'running']),
  const MenuFolder('Wireless', Icons.wifi, [
    MenuTable('WiFi Interfaces', Icons.wifi, '/interface/wireless',
        ['name', 'ssid', 'band', 'running']),
    MenuTable('Registration', Icons.devices,
        '/interface/wireless/registration-table',
        ['interface', 'mac-address', 'signal-strength', 'uptime'],
        readOnly: true),
    MenuTable('Security Profiles', Icons.security,
        '/interface/wireless/security-profiles', ['name', 'mode']),
  ]),
  const MenuFolder('Bridge', Icons.account_tree, [
    MenuTable('Bridge', Icons.account_tree, '/interface/bridge',
        ['name', 'running']),
    MenuTable('Ports', Icons.settings_input_component,
        '/interface/bridge/port', ['interface', 'bridge']),
  ]),
  const MenuFolder('PPP', Icons.vpn_key, [
    MenuTable('Secrets', Icons.key, '/ppp/secret',
        ['name', 'service', 'profile']),
    MenuTable('Active', Icons.online_prediction, '/ppp/active',
        ['name', 'address', 'uptime'],
        readOnly: true),
    MenuTable('Profiles', Icons.tune, '/ppp/profile',
        ['name', 'local-address']),
  ]),
  const MenuTable('Switch', Icons.dns, '/interface/ethernet/switch',
      ['name', 'type']),
  const MenuTable('Mesh', Icons.hub, '/interface/mesh', ['name', 'running']),
  MenuFolder('IP', Icons.public, <MenuNode>[
    MenuTable('Addresses', Icons.pin, '/ip/address',
        const ['address', 'interface'],
        fields: <FieldSpec>[
          ..._commentDisable,
          const FieldSpec('address', 'address', hint: '192.168.88.1/24'),
          const FieldSpec('interface', 'interface'),
          const FieldSpec('network', 'network'),
        ]),
    const MenuTable('ARP', Icons.device_hub, '/ip/arp',
        ['address', 'mac-address', 'interface']),
    const MenuTable('DHCP Server', Icons.dns_outlined, '/ip/dhcp-server',
        ['name', 'interface', 'address-pool']),
    MenuTable('DHCP Leases', Icons.devices_other, '/ip/dhcp-server/lease',
        const ['address', 'mac-address', 'host-name', 'status'],
        fields: <FieldSpec>[
          ..._commentDisable,
          const FieldSpec('address', 'address'),
          const FieldSpec('mac-address', 'mac-address'),
          const FieldSpec('server', 'server'),
        ]),
    MenuTable('DNS Static', Icons.dns, '/ip/dns/static',
        const ['name', 'address'],
        fields: <FieldSpec>[
          ..._commentDisable,
          const FieldSpec('name', 'name'),
          const FieldSpec('address', 'address'),
          const FieldSpec('ttl', 'ttl'),
        ]),
    MenuFolder('Firewall', Icons.local_fire_department, <MenuNode>[
      MenuTable('Filter Rules', Icons.filter_alt, '/ip/firewall/filter',
          const ['action', 'chain', 'protocol', 'dst-port'],
          fields: _firewallFields(nat: false)),
      MenuTable('NAT', Icons.swap_horiz, '/ip/firewall/nat',
          const ['action', 'chain', 'protocol', 'dst-port'],
          fields: _firewallFields(nat: true)),
      MenuTable('Mangle', Icons.edit_road, '/ip/firewall/mangle',
          const ['action', 'chain', 'protocol', 'dst-port'],
          fields: _firewallFields(nat: false)),
      MenuTable('Raw', Icons.bolt, '/ip/firewall/raw',
          const ['action', 'chain', 'protocol', 'dst-port'],
          fields: _firewallFields(nat: false)),
      const MenuTable('Service Ports', Icons.settings_input_hdmi,
          '/ip/firewall/service-port', ['name', 'ports']),
      const MenuTable('Connections', Icons.compare_arrows,
          '/ip/firewall/connection',
          ['protocol', 'src-address', 'dst-address'],
          readOnly: true),
      MenuTable('Address Lists', Icons.format_list_bulleted,
          '/ip/firewall/address-list', const ['list', 'address'],
          fields: <FieldSpec>[
            ..._commentDisable,
            const FieldSpec('list', 'list'),
            const FieldSpec('address', 'address'),
            const FieldSpec('timeout', 'timeout'),
          ]),
    ]),
    const MenuTable('Pool', Icons.view_module, '/ip/pool',
        ['name', 'ranges']),
    MenuTable('Routes', Icons.alt_route, '/ip/route',
        const ['dst-address', 'gateway', 'distance'],
        fields: <FieldSpec>[
          ..._commentDisable,
          const FieldSpec('dst-address', 'dst-address', hint: '0.0.0.0/0'),
          const FieldSpec('gateway', 'gateway'),
          const FieldSpec('distance', 'distance'),
        ]),
    const MenuTable('Services', Icons.miscellaneous_services, '/ip/service',
        ['name', 'port'],
        fields: [
          FieldSpec('disabled', 'disabled',
              isToggle: true, section: 'Comment/Disable'),
          FieldSpec('port', 'port'),
          FieldSpec('address', 'address', hint: 'дозволені адреси'),
        ]),
  ]),
  const MenuFolder('IPv6', Icons.public, [
    MenuTable('Addresses', Icons.pin, '/ipv6/address',
        ['address', 'interface']),
    MenuTable('Routes', Icons.alt_route, '/ipv6/route',
        ['dst-address', 'gateway']),
  ]),
  const MenuFolder('Routing', Icons.alt_route, [
    MenuTable('OSPF Instances', Icons.share, '/routing/ospf/instance',
        ['name', 'router-id']),
    MenuTable('BGP Connections', Icons.share, '/routing/bgp/connection',
        ['name', 'remote.address']),
  ]),
  const MenuFolder('System', Icons.settings, [
    MenuTable('Identity', Icons.badge, '/system/identity', ['name'],
        fields: [FieldSpec('name', 'name')]),
    MenuTable('Clock', Icons.schedule, '/system/clock',
        ['time', 'date', 'time-zone-name']),
    MenuTable('Users', Icons.people, '/user', ['name', 'group']),
    MenuTable('Packages', Icons.inventory_2, '/system/package',
        ['name', 'version'],
        readOnly: true),
    MenuTable('Scheduler', Icons.timer, '/system/scheduler',
        ['name', 'interval', 'next-run']),
    MenuTable('Scripts', Icons.code, '/system/script',
        ['name', 'run-count']),
    MenuTable('NTP Client', Icons.access_time, '/system/ntp-client',
        ['enabled', 'servers']),
    MenuTable('Health', Icons.favorite, '/system/health',
        ['name', 'value', 'type'],
        readOnly: true),
  ]),
  MenuFolder('Queues', Icons.speed, <MenuNode>[
    MenuTable('Simple Queues', Icons.speed, '/queue/simple',
        const ['name', 'target', 'max-limit'],
        fields: <FieldSpec>[
          ..._commentDisable,
          const FieldSpec('name', 'name'),
          const FieldSpec('target', 'target', hint: '192.168.88.10/32'),
          const FieldSpec('max-limit', 'max-limit',
              hint: '10M/10M (upload/download)'),
        ]),
    const MenuTable('Queue Tree', Icons.account_tree, '/queue/tree',
        ['name', 'parent', 'max-limit']),
  ]),
  const MenuTable('Radius', Icons.radar, '/radius', ['service', 'address']),
  const MenuTable('Files', Icons.folder, '/file',
      ['name', 'size', 'creation-time'],
      readOnly: true),
];
