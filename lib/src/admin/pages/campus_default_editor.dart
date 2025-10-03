import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CampusDefaultsEditor extends StatefulWidget {
  const CampusDefaultsEditor({super.key});

  @override
  State<CampusDefaultsEditor> createState() => _CampusDefaultsEditorState();
}

class _CampusDefaultsEditorState extends State<CampusDefaultsEditor> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCampusKey;

  // Text controllers for coordinates
  final _inLat = TextEditingController();
  final _inLng = TextEditingController();
  final _outLat = TextEditingController();
  final _outLng = TextEditingController();

  @override
  void dispose() {
    _inLat.dispose();
    _inLng.dispose();
    _outLat.dispose();
    _outLng.dispose();
    super.dispose();
  }

  Future<void> _saveCampusDefaults() async {
    if (_formKey.currentState!.validate() && _selectedCampusKey != null) {
      final campusKey = _selectedCampusKey!;
      await FirebaseFirestore.instance
          .collection('campus_defaults')
          .doc(campusKey)
          .set({
        'inLat': double.parse(_inLat.text),
        'inLng': double.parse(_inLng.text),
        'outLat': double.parse(_outLat.text),
        'outLng': double.parse(_outLng.text),
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved defaults for $campusKey')),
      );
    }
  }

  void _loadCampusDefaults(String campusKey) async {
    final snap = await FirebaseFirestore.instance
        .collection('campus_defaults')
        .doc(campusKey)
        .get();
    if (snap.exists) {
      final data = snap.data()!;
      _inLat.text = data['inLat'].toString();
      _inLng.text = data['inLng'].toString();
      _outLat.text = data['outLat'].toString();
      _outLng.text = data['outLng'].toString();
    } else {
      _inLat.clear();
      _inLng.clear();
      _outLat.clear();
      _outLng.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Defaults Editor')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('campus_defaults').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final campusKeys = docs.map((d) => d.id).toList();
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select campus'),
                  items: [
                    ...campusKeys.map(
                      (k) => DropdownMenuItem(value: k, child: Text(k)),
                    ),
                    const DropdownMenuItem(
                      value: '_new',
                      child: Text('Add new campus…'),
                    ),
                  ],
                  value: _selectedCampusKey,
                  onChanged: (v) {
                    setState(() => _selectedCampusKey = v);
                    if (v != null && v != '_new') {
                      _loadCampusDefaults(v);
                    } else {
                      _inLat.clear();
                      _inLng.clear();
                      _outLat.clear();
                      _outLng.clear();
                    }
                  },
                ),
                if (_selectedCampusKey == '_new' || _selectedCampusKey == null)
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'New campus key (id)'),
                    onChanged: (v) => _selectedCampusKey = v.trim(),
                  ),
                TextFormField(
                  controller: _inLat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Check-In Latitude'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _inLng,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Check-In Longitude'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _outLat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Check-Out Latitude'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _outLng,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Check-Out Longitude'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saveCampusDefaults,
                  child: const Text('Save Defaults'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
