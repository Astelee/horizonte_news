import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../services/avatar_upload_service.dart';

/// Bottom sheets reutilizáveis para edição de perfil (nome, ID de
/// usuário e foto). Usados tanto em Configurações quanto na aba
/// Perfil, para manter a mesma lógica em um único lugar.

void _showSnack(
  BuildContext context,
  String msg, {
  IconData? icon,
  bool success = false,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                color: success
                    ? const Color(0xFF4CAF50)
                    : AppColors.primaryOrange,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 6,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF141414),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: duration,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// EDITAR NOME
// ═══════════════════════════════════════════════════════════════════
void showEditDisplayNameSheet(
  BuildContext context, {
  required VoidCallback onSaved,
}) {
  final controller = TextEditingController(
    text: FirebaseAuth.instance.currentUser?.displayName ?? '',
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EDITAR NOME',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Seu nome',
                hintStyle: const TextStyle(color: Color(0xFF424242)),
                filled: true,
                fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF212121)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryOrange,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF212121)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;

                await FirebaseAuth.instance.currentUser
                    ?.updateDisplayName(newName);

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                  onSaved();
                  _showSnack(
                    context,
                    'Nome atualizado!',
                    icon: Icons.check_circle_rounded,
                    success: true,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFBF360C),
                      Color(0xFFE65100),
                      Color(0xFFF57C00),
                    ],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'SALVAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// EDITAR ID DE USUÁRIO
// ═══════════════════════════════════════════════════════════════════
String _formatUsername(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
}

void showEditUsernameSheet(
  BuildContext context, {
  required String? currentUsername,
  required void Function(String newUsername) onSaved,
}) {
  final user = FirebaseAuth.instance.currentUser;

  final usernameController = TextEditingController(
    text: currentUsername ?? '',
  );

  bool usernameAvailable = currentUsername != null;
  bool checkingUsername = false;
  String? usernameError;
  DateTime lastCheck = DateTime.now();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setModalState) {
        Future<void> checkUsernameAvailability(String username) async {
          if (username.length < 3) return;

          if (currentUsername != null && username == currentUsername) {
            setModalState(() {
              usernameAvailable = true;
              usernameError = null;
              checkingUsername = false;
            });
            return;
          }

          setModalState(() => checkingUsername = true);

          try {
            final query = await FirebaseFirestore.instance
                .collection('users_xp')
                .where('username', isEqualTo: username.toLowerCase())
                .limit(1)
                .get();

            usernameAvailable = query.docs.isEmpty;
            usernameError =
                query.docs.isEmpty ? null : 'Este ID já está em uso.';
            checkingUsername = false;
            setModalState(() {});
          } catch (_) {
            checkingUsername = false;
            setModalState(() {});
          }
        }

        void onUsernameChanged(String rawValue) {
          final formatted = _formatUsername(rawValue);
          if (formatted != rawValue) {
            usernameController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }

          setModalState(() {
            usernameAvailable = false;
            usernameError = null;
          });

          if (formatted.length < 3) return;

          lastCheck = DateTime.now();
          final checkTime = lastCheck;

          Future.delayed(const Duration(milliseconds: 600), () {
            if (checkTime == lastCheck) {
              checkUsernameAvailability(formatted);
            }
          });
        }

        Widget? usernameSuffix() {
          if (usernameController.text.trim().length < 3) return null;
          if (checkingUsername) {
            return const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryOrange,
                ),
              ),
            );
          }
          if (usernameAvailable) {
            return const Icon(Icons.check_circle_rounded, color: Colors.green);
          }
          if (usernameError != null) {
            return const Icon(Icons.cancel_rounded, color: Colors.redAccent);
          }
          return null;
        }

        String? usernameHelperText() {
          final value = usernameController.text.trim();
          if (value.isEmpty) return null;
          if (value.length < 3) return 'Mínimo de 3 caracteres.';
          if (checkingUsername) return 'Verificando disponibilidade...';
          if (usernameError != null) return usernameError;
          if (usernameAvailable) return 'ID disponível!';
          return null;
        }

        Color helperColor() {
          final value = usernameController.text.trim();
          if (usernameError != null) return Colors.redAccent;
          if (usernameAvailable && value.length >= 3) return Colors.green;
          return const Color(0xFF757575);
        }

        final usernameOk =
            usernameController.text.trim().length >= 3 && usernameAvailable;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0A0A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EDITAR ID',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: usernameController,
                    autofocus: true,
                    onChanged: onUsernameChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: '@',
                      prefixStyle: const TextStyle(color: Color(0xFF757575)),
                      hintText: 'seu_id',
                      hintStyle: const TextStyle(color: Color(0xFF424242)),
                      filled: true,
                      fillColor: const Color(0xFF141414),
                      suffixIcon: usernameSuffix(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF212121)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryOrange,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF212121)),
                      ),
                    ),
                  ),
                  if (usernameHelperText() != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      usernameHelperText()!,
                      style: TextStyle(
                        color: helperColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: (!usernameOk)
                        ? null
                        : () async {
                            final newUsername = usernameController.text
                                .trim()
                                .toLowerCase();

                            if (user == null) return;

                            try {
                              await FirebaseFirestore.instance
                                  .collection('users_xp')
                                  .doc(user.uid)
                                  .set({
                                'username': newUsername,
                              }, SetOptions(merge: true));

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                                onSaved(newUsername);
                                _showSnack(
                                  context,
                                  'ID atualizado!',
                                  icon: Icons.check_circle_rounded,
                                  success: true,
                                );
                              }
                            } catch (_) {
                              if (sheetContext.mounted) {
                                _showSnack(
                                  context,
                                  'Erro ao atualizar ID.',
                                  icon: Icons.error_rounded,
                                  success: false,
                                );
                              }
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: usernameOk
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFBF360C),
                                  Color(0xFFE65100),
                                  Color(0xFFF57C00),
                                ],
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF2A2A2A),
                                  Color(0xFF2A2A2A),
                                ],
                              ),
                      ),
                      child: const Center(
                        child: Text(
                          'SALVAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// TROCAR FOTO DE PERFIL
// ═══════════════════════════════════════════════════════════════════
Future<void> pickAndUploadAvatar(
  BuildContext context, {
  required void Function(String newPhotoUrl) onUploading,
  required void Function(String newPhotoUrl) onSaved,
  required void Function() onError,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1024,
  );

  if (picked == null) return;

  onUploading(picked.path);

  try {
    final avatarService = AvatarUploadService();
    final url = await avatarService.uploadAvatar(
      file: File(picked.path),
      uid: user.uid,
    );

    await FirebaseFirestore.instance
        .collection('users_xp')
        .doc(user.uid)
        .set({'photoUrl': url}, SetOptions(merge: true));

    await user.updatePhotoURL(url);

    onSaved(url);

    if (context.mounted) {
      _showSnack(
        context,
        'Foto de perfil atualizada!',
        icon: Icons.check_circle_rounded,
        success: true,
      );
    }
  } catch (e) {
    debugPrint('Erro no upload de avatar (Cloudinary): $e');
    onError();
    if (context.mounted) {
      _showSnack(
        context,
        'Erro ao enviar a foto.',
        icon: Icons.error_rounded,
        success: false,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// REMOVER FOTO DE PERFIL
// ═══════════════════════════════════════════════════════════════════
Future<void> removeAvatar(
  BuildContext context, {
  required void Function() onRemoving,
  required void Function() onRemoved,
  required void Function() onError,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  onRemoving();

  try {
    await FirebaseFirestore.instance
        .collection('users_xp')
        .doc(user.uid)
        .set({'photoUrl': FieldValue.delete()}, SetOptions(merge: true));

    await user.updatePhotoURL(null);

    onRemoved();

    if (context.mounted) {
      _showSnack(
        context,
        'Foto removida.',
        icon: Icons.check_circle_rounded,
        success: true,
      );
    }
  } catch (e) {
    debugPrint('Erro ao remover avatar: $e');
    onError();
    if (context.mounted) {
      _showSnack(
        context,
        'Erro ao remover a foto.',
        icon: Icons.error_rounded,
        success: false,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// MENU: TROCAR OU REMOVER FOTO
// ═══════════════════════════════════════════════════════════════════
/// Mostra um menu com as opções "Trocar foto" e "Remover foto" quando
/// já existe uma foto de perfil. Se [hasPhoto] for falso, pula direto
/// para a galeria (não faz sentido oferecer "remover" sem foto).
Future<void> showAvatarOptionsSheet(
  BuildContext context, {
  required bool hasPhoto,
  required void Function(String newPhotoUrl) onUploading,
  required void Function(String newPhotoUrl) onSaved,
  required void Function() onRemoving,
  required void Function() onRemoved,
  required void Function() onError,
}) async {
  if (!hasPhoto) {
    await pickAndUploadAvatar(
      context,
      onUploading: onUploading,
      onSaved: onSaved,
      onError: onError,
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primaryOrange,
              ),
              title: const Text(
                'Trocar foto',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                pickAndUploadAvatar(
                  context,
                  onUploading: onUploading,
                  onSaved: onSaved,
                  onError: onError,
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Remover foto',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                removeAvatar(
                  context,
                  onRemoving: onRemoving,
                  onRemoved: onRemoved,
                  onError: onError,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}