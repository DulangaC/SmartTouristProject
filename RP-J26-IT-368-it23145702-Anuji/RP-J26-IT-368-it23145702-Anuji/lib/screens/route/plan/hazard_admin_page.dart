import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Research prototype admin form. API key is entered per session, never embedded.
class HazardAdminPage extends StatefulWidget {
  const HazardAdminPage({super.key});
  @override
  State<HazardAdminPage> createState() => _HazardAdminPageState();
}

class _HazardAdminPageState extends State<HazardAdminPage> {
  static const base = 'http://127.0.0.1:8001';
  final _form = GlobalKey<FormState>();
  final _key = TextEditingController();
  final _type = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _description = TextEditingController();
  String _severity = 'Medium';
  bool _busy = false;
  String? _message;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() {
    _key.dispose(); _type.dispose(); _lat.dispose(); _lon.dispose(); _description.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final r = await http.get(Uri.parse('$base/api/hazards?active_only=true'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('API ${r.statusCode}');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _reports = (data['hazards'] as List).whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v)).toList());
    } catch (e) {
      if (mounted) setState(() => _message = 'Cannot load reports: $e');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _message = null; });
    try {
      final r = await http.post(Uri.parse('$base/api/hazards/report'),
        headers: {'Content-Type':'application/json', 'X-Admin-Key':_key.text.trim()},
        body: jsonEncode({'hazard_type':_type.text.trim(),
          'latitude':double.parse(_lat.text.trim()), 'longitude':double.parse(_lon.text.trim()),
          'severity':_severity, 'description':_description.text.trim()}),
      ).timeout(const Duration(seconds: 25));
      if (r.statusCode != 201) throw Exception('API ${r.statusCode}: ${r.body}');
      if (!mounted) return;
      setState(() => _message = 'Hazard report saved. It is unverified until reviewed.');
      _type.clear(); _lat.clear(); _lon.clear(); _description.clear();
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _message = 'Save failed: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _resolve(int id) async {
    if (_key.text.trim().isEmpty) {
      setState(() => _message = 'Enter your admin key first.'); return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final r = await http.patch(Uri.parse('$base/api/hazards/$id/resolve'),
        headers: {'X-Admin-Key':_key.text.trim()}).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('API ${r.statusCode}: ${r.body}');
      await _refresh();
      if (mounted) setState(() => _message = 'Report #$id resolved.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Resolve failed: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  String? _coordinate(String? v, double low, double high) {
    final d = double.tryParse((v ?? '').trim());
    return d == null || !d.isFinite || d < low || d > high ? 'Enter a valid coordinate ($low to $high)' : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hazard administration')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Research demo only. Admin actions require the backend API key. Do not use real secrets on shared/public computers.'),
      const SizedBox(height: 12),
      Form(key: _form, child: Column(children: [
        TextFormField(controller:_key, obscureText:true, decoration:const InputDecoration(labelText:'Admin API key'),
          validator:(v) => (v ?? '').trim().isEmpty ? 'Admin key required' : null),
        TextFormField(controller:_type, decoration:const InputDecoration(labelText:'Hazard type (e.g. road blockage)'),
          validator:(v) => (v ?? '').trim().length < 2 ? 'Enter hazard type' : null),
        TextFormField(controller:_lat, keyboardType:const TextInputType.numberWithOptions(decimal:true, signed:true),
          decoration:const InputDecoration(labelText:'Latitude'), validator:(v) => _coordinate(v,-90,90)),
        TextFormField(controller:_lon, keyboardType:const TextInputType.numberWithOptions(decimal:true, signed:true),
          decoration:const InputDecoration(labelText:'Longitude'), validator:(v) => _coordinate(v,-180,180)),
        DropdownButtonFormField<String>(value:_severity, decoration:const InputDecoration(labelText:'Severity'),
          items:['Low','Medium','High'].map((s) => DropdownMenuItem(value:s,child:Text(s))).toList(),
          onChanged:(v) { if (v != null) setState(() => _severity=v); }),
        TextFormField(controller:_description, maxLines:3, decoration:const InputDecoration(labelText:'Description'),
          validator:(v) => (v ?? '').trim().length < 3 ? 'Enter a description' : null),
      ])),
      const SizedBox(height: 14),
      ElevatedButton(onPressed:_busy ? null : _save, child:Text(_busy ? 'Please wait...' : 'Add hazard report')),
      if (_message != null) Padding(padding:const EdgeInsets.symmetric(vertical:12), child:SelectableText(_message!)),
      const Divider(),
      Row(children:[const Expanded(child:Text('Active hazard reports',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),
        IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),
      for (final r in _reports) Card(child:ListTile(
        title:Text('${r['hazard_type']} — ${r['severity']}'),
        subtitle:Text('#${r['id']} | ${r['latitude']}, ${r['longitude']}\n${r['description']}\nUnverified report'),
        isThreeLine:true,
        trailing:TextButton(onPressed:_busy ? null : () => _resolve(r['id'] as int),child:const Text('Resolve')),
      )),
    ]),
  );
}
