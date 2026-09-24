/// Utilitário centralizado para gerar iniciais a partir do nome do usuário.
///
/// Regras:
/// 1. Nome e sobrenome → primeira letra do primeiro nome + primeira letra
///    do último nome (ex.: "Diego Magno" → "DM").
/// 2. Apenas um nome → primeira letra (ex.: "Maria" → "M").
/// 3. Espaços extras são ignorados.
/// 4. Letras sempre em maiúsculas.
/// 5. Emojis, símbolos e outros caracteres não-alfanuméricos são
///    ignorados na busca pela primeira letra "de verdade" (ex.:
///    "💕 Ruivinha" → "R", "🌶️🔥" → "?").
/// 6. Nome vazio/nulo, ou nome sem nenhuma letra/número utilizável
///    (ex.: só emojis) → fallback "?".
class InitialsHelper {
  InitialsHelper._();

  /// Caracteres válidos para virar inicial: letras Unicode (inclui
  /// acentuadas, cirílico, etc.) e dígitos. Emojis, símbolos, pontuação
  /// e variation selectors ficam de fora.
  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Extrai a primeira letra/dígito "de verdade" de uma palavra,
  /// varrendo por *runes* (code points completos) em vez de
  /// code units — evita cortar um emoji ao meio e devolver um
  /// glifo inválido. Retorna null se a palavra não tiver nenhum
  /// caractere alfanumérico (ex.: for só emoji/símbolo).
  static String? _firstLetter(String word) {
    for (final rune in word.runes) {
      final char = String.fromCharCode(rune);
      if (_letterOrDigit.hasMatch(char)) {
        return char.toUpperCase();
      }
    }
    return null;
  }

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
      return _firstLetter(parts.first) ?? '?';
    }

    final first = _firstLetter(parts.first);
    final last = _firstLetter(parts.last);

    if (first == null && last == null) return '?';
    return (first ?? '') + (last ?? '');
  }
}
