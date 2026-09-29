import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Título + texto escritos pelo admin.
class AdminPushMessage {
  final String title;
  final String body;
  const AdminPushMessage(this.title, this.body);
}

/// Caixa para o admin escrever (ou editar) um push antes de enviar.
/// Devolve [AdminPushMessage] ao confirmar, ou null ao cancelar.
class AdminPushDialog extends StatefulWidget {
  final String dialogTitle;

  /// Aviso de quem vai receber (ex.: "Só Diego receberá").
  final String targetInfo;
  final String initialTitle;
  final String initialBody;
  final String confirmLabel;

  const AdminPushDialog({
    required this.dialogTitle,
    required this.targetInfo,
    this.initialTitle = '',
    this.initialBody = '',
    this.confirmLabel = 'Enviar',
    Key? key,
  }) : super(key: key);

  @override
  State<AdminPushDialog> createState() => _AdminPushDialogState();
}

class _AdminPushDialogState extends State<AdminPushDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _body = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: AppColors.primaryOrange.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: AppColors.primaryOrange.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryOrange),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.2)),
      ),
      title: Text(
        widget.dialogTitle,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.targetInfo,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              maxLength: 60,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Título'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLength: 240,
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Mensagem'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final t = _title.text.trim();
            final b = _body.text.trim();
            if (t.isEmpty || b.isEmpty) return;
            Navigator.pop(context, AdminPushMessage(t, b));
          },
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}