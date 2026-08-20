/// Utilitário centralizado para gerar iniciais a partir do nome do usuário.
///
/// Regras:
/// 1. Nome e sobrenome → primeira letra do primeiro nome + primeira letra
///    do último nome (ex.: "Diego Magno" → "DM").
/// 2. Apenas um nome → primeira letra (ex.: "Maria" → "M").
/// 3. Espaços extras são ignorados.
/// 4. Letras sempre em maiúsculas.
/// 5. Nome vazio/nulo → fallback "?".
class InitialsHelper {
  InitialsHelper._();

  /// Gera as iniciais a partir de um nome. Usado por [AppAvatar] e por
  /// qualquer outro ponto do app que precise exibir iniciais — nunca
  /// duplique essa lógica em outro lugar.
  static String getInitials(String? name) {
    if (name == null) return '?';

    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    final first = parts.first[0];
    final last = parts.last[0];
    return (first + last).toUpperCase();
  }
}
