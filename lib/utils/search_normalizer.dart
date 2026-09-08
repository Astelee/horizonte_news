/// Utilitário de normalização de texto para busca.
///
/// O Firestore não tem full-text search nativo, então a estratégia
/// usada aqui é indexar, junto de cada notícia, uma versão
/// normalizada do título (minúscula, sem acento) e a lista de
/// palavras que a compõem. A busca do usuário passa pela mesma
/// normalização antes de consultar, o que torna o resultado
/// insensível a maiúsculas/minúsculas e a acentuação, e permite
/// encontrar por qualquer palavra do título — não só pelo começo.
class SearchNormalizer {
  SearchNormalizer._();

  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// Remove acentuação e converte para minúsculas.
  static String normalize(String input) {
    final lower = input.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_accentMap[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Quebra o texto normalizado em palavras (tokens) de pelo menos
  /// 2 caracteres, sem repetição — usadas em uma query
  /// `array-contains-any` para achar a notícia por qualquer palavra
  /// do título, não só pelo prefixo inteiro.
  static List<String> tokenize(String input) {
    final normalized = normalize(input);
    final rawWords = normalized.split(RegExp(r'[^a-z0-9]+'));
    final seen = <String>{};
    final tokens = <String>[];
    for (final w in rawWords) {
      if (w.length >= 2 && seen.add(w)) {
        tokens.add(w);
      }
    }
    return tokens;
  }
}