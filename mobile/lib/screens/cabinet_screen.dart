import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/case_list_tile.dart';

class CabinetScreen extends StatefulWidget {
  const CabinetScreen({super.key});

  @override
  State<CabinetScreen> createState() => _CabinetScreenState();
}

class _CabinetScreenState extends State<CabinetScreen> {
  final _api = ApiService();

  List<CourtCase> _cases = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cases = await _api.getMyCases();
      setState(() => _cases = cases);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мої справи')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Спробувати ще раз')),
          ),
        ],
      );
    }
    if (_cases.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Справ не знайдено')),
        ],
      );
    }
    return ListView.builder(
      itemCount: _cases.length,
      itemBuilder: (context, index) {
        final c = _cases[index];
        return CaseListTile(
          courtCase: c,
          onTap: c.url.isEmpty
              ? null
              : () => launchUrl(Uri.parse(c.url), mode: LaunchMode.externalApplication),
        );
      },
    );
  }
}
