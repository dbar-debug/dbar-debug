import 'package:flutter/material.dart';

import '../config/menu_tree.dart';
import '../services/routeros_client.dart';
import 'item_list_screen.dart';

/// Браузер дерева "Налаштування роутера" (Router Settings):
/// CAPsMAN, Interfaces, Wireless, Bridge, PPP, IP, System, Queues тощо.
class RouterSettingsScreen extends StatelessWidget {
  final RouterOSClient client;
  final String title;
  final List<MenuNode> nodes;

  RouterSettingsScreen({
    super.key,
    required this.client,
    this.title = 'Налаштування роутера',
    List<MenuNode>? nodes,
  }) : nodes = nodes ?? routerSettingsMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: nodes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final node = nodes[i];
          return ListTile(
            leading: Icon(node.icon),
            title: Text(node.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (node is MenuFolder) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RouterSettingsScreen(
                    client: client,
                    title: node.title,
                    nodes: node.children,
                  ),
                ));
              } else if (node is MenuTable) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ItemListScreen(client: client, table: node),
                ));
              }
            },
          );
        },
      ),
    );
  }
}
