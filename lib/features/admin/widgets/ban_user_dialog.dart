import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class BanUserDialog extends StatefulWidget {
  final String authorName;
  const BanUserDialog({required this.authorName, Key? key})
      : super(key: key);

  @override
  State<BanUserDialog> createState() => _BanUserDialogState();
}

class _BanUserDialogState extends State<BanUserDialog> {
  final _reasonCtrl = TextEditingController();
  int _selectedDays = 7;
  bool _permanent = false;

  static const _options = [
    {'label': '1 dia', 'days': 1},
    {'label': '3 dias', 'days': 3},
    {'label': '7 dias', 'days': 7},
    {'label': '15 dias', 'days': 15},
    {'label': '30 dias', 'days': 30},
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.person_off_rounded,
              color: Color(0xFFFF9800), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Banir ${widget.authorName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O usuário ficará impedido de comentar.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Motivo do banimento',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ex: Spam, linguagem ofensiva...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.5),
                  fontSize: 12,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFFFF9800), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Duração',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  setState(() => _permanent = !_permanent),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _permanent
                      ? const Color(0xFFEF5350).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _permanent
                        ? const Color(0xFFEF5350)
                        : AppColors.borderDark,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _permanent
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: _permanent
                          ? const Color(0xFFEF5350)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Banimento permanente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_permanent)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options.map((opt) {
                  final days = opt['days'] as int;
                  final selected = _selectedDays == days;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedDays = days),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFF9800)
                                .withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFF9800)
                              : AppColors.borderDark,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        opt['label'] as String,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFFF9800)
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
            final reason = _reasonCtrl.text.trim();
            if (reason.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Informe o motivo do banimento.'),
                  backgroundColor: Color(0xFFEF5350),
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'reason': reason,
              'days': _permanent ? 0 : _selectedDays,
            });
          },
          child: const Text(
            'Banir',
            style: TextStyle(
              color: Color(0xFFFF9800),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
