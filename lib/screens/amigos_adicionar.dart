import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'amigos_modelos.dart';
import 'amigos_widgets.dart';

class BotaoAdicionarAmigo extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const BotaoAdicionarAmigo({Key? key, required this.myUid, required this.db})
      : super(key: key);

  void _abrir(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PainelAdicionarAmigo(myUid: myUid, db: db),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrir(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'ADICIONAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PainelAdicionarAmigo extends StatefulWidget {
  final String myUid;
  final FirebaseFirestore db;

  const PainelAdicionarAmigo({Key? key, required this.myUid, required this.db})
      : super(key: key);

  @override
  State<PainelAdicionarAmigo> createState() => _PainelAdicionarAmigoState();
}

class _PainelAdicionarAmigoState extends State<PainelAdicionarAmigo> {
  final _controller = TextEditingController();
  FriendModel? _usuarioEncontrado;
  bool _buscando = false;
  bool _enviando = false;
  String? _mensagem;
  bool _isErro = false;
  String? _statusSolicitacao;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return;

    setState(() {
      _buscando = true;
      _usuarioEncontrado = null;
      _mensagem = null;
      _statusSolicitacao = null;
    });

    HapticFeedback.lightImpact();

    try {
      final snap = await widget.db
          .collection('users_xp')
          .where('username', isEqualTo: query)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _mensagem = 'Nenhum usuário encontrado com @$query';
          _isErro = true;
          _buscando = false;
        });
        return;
      }

      final user = FriendModel.fromDoc(snap.docs.first);

      if (user.uid == widget.myUid) {
        setState(() {
          _mensagem = 'Você não pode se adicionar.';
          _isErro = true;
          _buscando = false;
        });
        return;
      }

      final existing = await widget.db
          .collection('friend_requests')
          .where('participants', arrayContains: widget.myUid)
          .get();

      String? existingStatus;
      for (final doc in existing.docs) {
        final d = doc.data();
        final parts = List<String>.from(d['participants'] ?? []);
        if (parts.contains(user.uid)) {
          existingStatus = d['status'] as String?;
          break;
        }
      }

      setState(() {
        _usuarioEncontrado = user;
        _statusSolicitacao = existingStatus;
        _buscando = false;
      });
    } catch (e) {
      setState(() {
        _mensagem = 'Erro ao buscar. Tente novamente.';
        _isErro = true;
        _buscando = false;
      });
    }
  }

  Future<void> _enviarSolicitacao() async {
    if (_usuarioEncontrado == null) return;
    setState(() => _enviando = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.db.collection('friend_requests').add({
        'fromUid': widget.myUid,
        'toUid': _usuarioEncontrado!.uid,
        'participants': [widget.myUid, _usuarioEncontrado!.uid],
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _mensagem = 'Solicitação enviada para @${_usuarioEncontrado!.username}!';
        _isErro = false;
        _usuarioEncontrado = null;
        _controller.clear();
        _enviando = false;
      });

      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() {
        _mensagem = 'Erro ao enviar. Tente novamente.';
        _isErro = true;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A)),
          left: BorderSide(color: Color(0xFF111111)),
          right: BorderSide(color: Color(0xFF111111)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_search_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BUSCAR AMIGO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                  Text('Digite o @ do usuário',
                      style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E1E1E)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onSubmitted: (_) => _buscar(),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                      TextInputFormatter.withFunction((old, newVal) {
                        return newVal.copyWith(text: newVal.text.toLowerCase());
                      }),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'ex: joao_silva123',
                      hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 15),
                      prefixText: '@  ',
                      prefixStyle: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _buscando ? null : _buscar,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buscando
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : const Icon(Icons.search_rounded,
                          color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          if (_mensagem != null) ...[
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _isErro
                    ? const Color(0xFFED4245).withOpacity(0.08)
                    : const Color(0xFF43B581).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isErro
                      ? const Color(0xFFED4245).withOpacity(0.3)
                      : const Color(0xFF43B581).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isErro
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: _isErro
                        ? const Color(0xFFED4245)
                        : const Color(0xFF43B581),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_mensagem!,
                        style: TextStyle(
                            color: _isErro
                                ? const Color(0xFFED4245)
                                : const Color(0xFF43B581),
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          if (_usuarioEncontrado != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFFFF6B00).withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AmigoAvatar(friend: _usuarioEncontrado!),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_usuarioEncontrado!.displayName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Text('@${_usuarioEncontrado!.username}',
                                style: TextStyle(
                                    color: const Color(0xFFFF6B00).withOpacity(0.7),
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                NivelBadge(level: _usuarioEncontrado!.level),
                                const SizedBox(width: 6),
                                Text('${_usuarioEncontrado!.totalXp} XP',
                                    style: const TextStyle(
                                        color: Color(0xFF555555), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_statusSolicitacao == 'accepted')
                    _BannerStatus(
                      icon: Icons.people_rounded,
                      texto: 'Vocês já são amigos!',
                      cor: const Color(0xFFFF6B00),
                    )
                  else if (_statusSolicitacao == 'pending')
                    _BannerStatus(
                      icon: Icons.hourglass_top_rounded,
                      texto: 'Solicitação já enviada',
                      cor: const Color(0xFFFAA61A),
                    )
                  else
                    GestureDetector(
                      onTap: _enviando ? null : _enviarSolicitacao,
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withOpacity(0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _enviando
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_add_rounded,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('ENVIAR SOLICITAÇÃO',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BannerStatus extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color cor;

  const _BannerStatus({required this.icon, required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cor.withOpacity(0.08),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: cor, size: 16),
          const SizedBox(width: 8),
          Text(texto,
              style: TextStyle(
                  color: cor, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
