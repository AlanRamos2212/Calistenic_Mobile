import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../services/support_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _service = SupportService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'OTRO';
  File? _image;
  bool _sending = false;
  List<SupportReport> _mine = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final list = await _service.mine();
      if (mounted) setState(() => _mine = list);
    } on ApiException {
      // best effort: the form stays usable
    }
  }

  void _snack(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) setState(() => _image = File(picked.path));
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      _snack('Completa título y descripción.', ok: false);
      return;
    }
    setState(() => _sending = true);
    FocusScope.of(context).unfocus();
    try {
      final created = await _service.create(
        _titleCtrl.text.trim(),
        _descCtrl.text.trim(),
        _category,
        image: _image,
      );
      if (!mounted) return;
      _titleCtrl.clear();
      _descCtrl.clear();
      _image = null;
      _snack('Caso #${created.id} registrado (OPEN).');
      _refresh();
    } on ApiException catch (e) {
      _snack(e.message, ok: false);
    } catch (e) {
      _snack('No se pudo enviar el reporte: $e', ok: false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrameScaffold(
      title: 'Soporte técnico',
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: Text('Reporta un bug: queda guardado en la BD (Práctica 7).'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: TextField(controller: _titleCtrl, maxLength: 120, decoration: const InputDecoration(labelText: 'Título')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: const [
                DropdownMenuItem(value: 'CRASH', child: Text('Crash / cierre súbito')),
                DropdownMenuItem(value: 'UI', child: Text('Interfaz')),
                DropdownMenuItem(value: 'DATOS', child: Text('Datos')),
                DropdownMenuItem(value: 'RED', child: Text('Conectividad')),
                DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'OTRO'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: TextField(
              controller: _descCtrl,
              maxLength: 4000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción (pasos para reproducirlo)'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.photo), label: Text(_image == null ? 'Adjuntar captura (opcional)' : 'Captura lista ✓')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enviar reporte'),
            ),
          ),
          const Divider(),
          const Text('Mis reportes', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_mine.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Sin reportes todavía.')),
          for (final r in _mine)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('#${r.id} ${r.title}'),
              subtitle: Text(r.createdAt),
              trailing: Chip(label: Text(r.status, style: const TextStyle(fontSize: 10))),
            ),
        ],
      ),
    );
  }
}
