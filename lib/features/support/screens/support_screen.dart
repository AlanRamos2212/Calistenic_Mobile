import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../services/support_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _service = SupportService();
  final _auth = AuthService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'OTRO';
  File? _image;
  bool _sending = false;
  bool _isAdmin = false;
  List<SupportReport> _mine = [];
  List<SupportReport> _all = [];
  String _adminFilter = '';
  bool _loadingAll = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _refresh();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    try {
      final role = await _auth.getUserRole();
      if (mounted) setState(() => _isAdmin == true ? _isAdmin : role == 'ADMIN');
    } catch (_) {
      // best effort
    }
  }

  Future<void> _refresh() async {
    try {
      final list = await _service.mine();
      if (mounted) setState(() => _mine = list);
    } on ApiException {
      // best effort: the form stays usable
    }
    if (_isAdmin) await _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loadingAll = true);
    try {
      final list = await _service.all(status: _adminFilter.isEmpty ? null : _adminFilter);
      if (mounted) setState(() => _all = list);
    } on ApiException {
      // best effort
    } finally {
      if (mounted) setState(() => _loadingAll = false);
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

  Future<void> _changeStatus(int id, String status) async {
    try {
      await _service.updateStatus(id, status);
      _snack('Caso #$id → $status.', ok: true);
      _loadAll();
    } on ApiException catch (e) {
      _snack(e.message, ok: false);
    } catch (e) {
      _snack('No se pudo actualizar el caso: $e', ok: false);
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
          // ── Form: reportar bug (usuario) ─────────────────────────────
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

          // ── Mis reportes (usuario) ───────────────────────────────────
          const Text('Mis reportes', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_mine.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Sin reportes todavía.')),
          for (final r in _mine)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('#${r.id} ${r.title}'),
                subtitle: Text(r.createdAt),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(label: Text(r.status, style: const TextStyle(fontSize: 10))),
                    if (r.imageUrl != null && r.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: r.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(width: 60, height: 60, color: AppColors.subtext.withValues(alpha: 0.1)),
                          errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 32),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Panel ADMIN (solo si rol = ADMIN) ────────────────────────
          if (_isAdmin) ...[
            const Divider(),
            const Text('Panel ADMIN - Todos los casos', style: TextStyle(fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _adminFilter.isEmpty ? null : _adminFilter,
                decoration: const InputDecoration(labelText: 'Filtrar por estado'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('En proceso')),
                  DropdownMenuItem(value: 'RESOLVED', child: Text('Resuelto')),
                ],
                onChanged: (v) {
                  setState(() => _adminFilter = v ?? '');
                  _loadAll();
                },
              ),
            ),
            if (_loadingAll)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()),
            if (_all.isEmpty && !_loadingAll) const Text('Sin casos todavía.'),
            for (final r in _all)
              ExpansionTile(
                key: ValueKey(r.id),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.blue.withValues(alpha: 0.15),
                  child: Text('#${r.id}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.blue)),
                ),
                title: Text(r.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${r.userName ?? 'Usuario'} · ${r.category}'),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.imageUrl != null && r.imageUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: r.imageUrl!,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                                width: 90, height: 90,
                                color: AppColors.subtext.withValues(alpha: 0.1)),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image, size: 32),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.description ?? '',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Chip(
                                    label: Text(r.status,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.white)),
                                    backgroundColor: _statusColor(r.status)),
                                const SizedBox(width: 12),
                                Text('Creado: ${r.createdAt}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.subtext)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                  labelText: 'Cambiar estado'),
                              initialValue: r.status,
                              items: const [
                                DropdownMenuItem(
                                    value: 'OPEN', child: Text('OPEN')),
                                DropdownMenuItem(value: 'IN_PROGRESS',
                                    child: Text('En proceso')),
                                DropdownMenuItem(value: 'RESOLVED',
                                    child: Text('Resuelto')),
                              ],
                              onChanged: (v) => v != null
                                  ? _changeStatus(r.id, v)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'RESOLVED':
        return Colors.green;
      default:
        return AppColors.subtext;
    }
  }
}
