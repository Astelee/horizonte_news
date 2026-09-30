import 'package:flutter/material.dart';

enum PetSpecies {
  fox, owl, cat, wolf, falcon, rabbit, tiger, deer, bear, shark,
  dolphin, dragon, phoenix, unicorn, griffin, kraken, dinosaur, lion,
  panther, eagle, pegasus, serpent, kitsune, raccoon, butterfly,
  turtle, raven, mammoth, celestialHound, cosmicDragon,
}

class PetDef {
  final String id;
  final int levelRequired;
  final String name;
  final String description;
  final PetSpecies species;
  final Color primary;
  final Color secondary;
  final Color accent;

  const PetDef({
    required this.id,
    required this.levelRequired,
    required this.name,
    required this.description,
    required this.species,
    required this.primary,
    required this.secondary,
    required this.accent,
  });
}

class PetCatalog {
  static const List<PetDef> all = [
    PetDef(id: 'pet_01', levelRequired: 1, name: 'Raposa Aurora', description: 'Uma pequena companheira envolta em luz polar.', species: PetSpecies.fox, primary: Color(0xFFFF8A3D), secondary: Color(0xFFFFD180), accent: Color(0xFFFF6B00)),
    PetDef(id: 'pet_02', levelRequired: 2, name: 'Coruja Lunar', description: 'Olhos atentos sob um brilho azul de lua.', species: PetSpecies.owl, primary: Color(0xFF64B5F6), secondary: Color(0xFFB3E5FC), accent: Color(0xFF2979FF)),
    PetDef(id: 'pet_03', levelRequired: 3, name: 'Gato Estelar', description: 'Um felino curioso com poeira de estrelas.', species: PetSpecies.cat, primary: Color(0xFFAB7BFF), secondary: Color(0xFFE1BEE7), accent: Color(0xFF7C4DFF)),
    PetDef(id: 'pet_04', levelRequired: 4, name: 'Lobo Boreal', description: 'Guardião de uma aurora azul-esverdeada.', species: PetSpecies.wolf, primary: Color(0xFF26C6DA), secondary: Color(0xFFB2EBF2), accent: Color(0xFF00B8D4)),
    PetDef(id: 'pet_05', levelRequired: 5, name: 'Falcão Solar', description: 'Voa entre faíscas douradas.', species: PetSpecies.falcon, primary: Color(0xFFFFC107), secondary: Color(0xFFFFF59D), accent: Color(0xFFFF8F00)),
    PetDef(id: 'pet_06', levelRequired: 6, name: 'Coelho Celeste', description: 'Leve como uma nuvem e brilhante como uma estrela.', species: PetSpecies.rabbit, primary: Color(0xFFE0F7FA), secondary: Color(0xFF80DEEA), accent: Color(0xFF26A69A)),
    PetDef(id: 'pet_07', levelRequired: 7, name: 'Tigre Esmeralda', description: 'Um felino poderoso cercado por energia verde.', species: PetSpecies.tiger, primary: Color(0xFF66BB6A), secondary: Color(0xFFC5E1A5), accent: Color(0xFF00C853)),
    PetDef(id: 'pet_08', levelRequired: 8, name: 'Cervo Encantado', description: 'Chifres iluminados por partículas mágicas.', species: PetSpecies.deer, primary: Color(0xFFBCAAA4), secondary: Color(0xFFFFE0B2), accent: Color(0xFF8D6E63)),
    PetDef(id: 'pet_09', levelRequired: 9, name: 'Urso Ártico', description: 'Forte, sereno e envolto em gelo luminoso.', species: PetSpecies.bear, primary: Color(0xFFB0BEC5), secondary: Color(0xFFECEFF1), accent: Color(0xFF90CAF9)),
    PetDef(id: 'pet_10', levelRequired: 10, name: 'Tubarão Abissal', description: 'Uma sombra azul das profundezas.', species: PetSpecies.shark, primary: Color(0xFF1565C0), secondary: Color(0xFF81D4FA), accent: Color(0xFF00E5FF)),
    PetDef(id: 'pet_11', levelRequired: 11, name: 'Golfinho Azul', description: 'Energia oceânica em movimento.', species: PetSpecies.dolphin, primary: Color(0xFF29B6F6), secondary: Color(0xFFB3E5FC), accent: Color(0xFF40C4FF)),
    PetDef(id: 'pet_12', levelRequired: 12, name: 'Dragão Rubi', description: 'Uma criatura dracônica cercada por brasas.', species: PetSpecies.dragon, primary: Color(0xFFE53935), secondary: Color(0xFFFF8A65), accent: Color(0xFFFF6D00)),
    PetDef(id: 'pet_13', levelRequired: 13, name: 'Fênix Flamejante', description: 'Renascida em fogo e luz.', species: PetSpecies.phoenix, primary: Color(0xFFFF5722), secondary: Color(0xFFFFD54F), accent: Color(0xFFFF1744)),
    PetDef(id: 'pet_14', levelRequired: 14, name: 'Unicórnio Prismático', description: 'Um brilho mágico em todas as cores.', species: PetSpecies.unicorn, primary: Color(0xFFE040FB), secondary: Color(0xFF80D8FF), accent: Color(0xFFFFEA00)),
    PetDef(id: 'pet_15', levelRequired: 15, name: 'Grifo Dourado', description: 'Guardião majestoso de energia dourada.', species: PetSpecies.griffin, primary: Color(0xFFFFB300), secondary: Color(0xFFFFE082), accent: Color(0xFFFF6F00)),
    PetDef(id: 'pet_16', levelRequired: 16, name: 'Kraken Cósmico', description: 'Tentáculos banhados por luz estelar.', species: PetSpecies.kraken, primary: Color(0xFF7E57C2), secondary: Color(0xFFCE93D8), accent: Color(0xFF00E5FF)),
    PetDef(id: 'pet_17', levelRequired: 17, name: 'Tiranossauro Ancestral', description: 'Um gigante pré-histórico reimaginado em energia.', species: PetSpecies.dinosaur, primary: Color(0xFF8BC34A), secondary: Color(0xFFDCE775), accent: Color(0xFF64DD17)),
    PetDef(id: 'pet_18', levelRequired: 18, name: 'Leão Imperial', description: 'Uma juba de luz envolve o rei dos animais.', species: PetSpecies.lion, primary: Color(0xFFFF9800), secondary: Color(0xFFFFE082), accent: Color(0xFFFFC400)),
    PetDef(id: 'pet_19', levelRequired: 19, name: 'Pantera Sombria', description: 'Elegante, silenciosa e cercada por energia violeta.', species: PetSpecies.panther, primary: Color(0xFF5E35B1), secondary: Color(0xFFB39DDB), accent: Color(0xFFE040FB)),
    PetDef(id: 'pet_20', levelRequired: 20, name: 'Águia Celestial', description: 'Asas abertas dentro de uma aurora estelar.', species: PetSpecies.eagle, primary: Color(0xFF42A5F5), secondary: Color(0xFFE3F2FD), accent: Color(0xFFFFD740)),
    PetDef(id: 'pet_21', levelRequired: 21, name: 'Pégaso Lunar', description: 'Asas luminosas de uma criatura das estrelas.', species: PetSpecies.pegasus, primary: Color(0xFF80CBC4), secondary: Color(0xFFE0F2F1), accent: Color(0xFF64FFDA)),
    PetDef(id: 'pet_22', levelRequired: 22, name: 'Serpente Astral', description: 'Uma serpente de energia que percorre o cosmos.', species: PetSpecies.serpent, primary: Color(0xFF26A69A), secondary: Color(0xFFB2DFDB), accent: Color(0xFFFFD740)),
    PetDef(id: 'pet_23', levelRequired: 23, name: 'Kitsune de Fogo', description: 'Raposa mística com caudas feitas de chamas.', species: PetSpecies.kitsune, primary: Color(0xFFFF7043), secondary: Color(0xFFFFCC80), accent: Color(0xFFFF1744)),
    PetDef(id: 'pet_24', levelRequired: 24, name: 'Guaxinim Nebuloso', description: 'Pequeno explorador cercado por uma nebulosa.', species: PetSpecies.raccoon, primary: Color(0xFF78909C), secondary: Color(0xFFCFD8DC), accent: Color(0xFF7C4DFF)),
    PetDef(id: 'pet_25', levelRequired: 25, name: 'Borboleta Astral', description: 'Asas delicadas com brilho cósmico.', species: PetSpecies.butterfly, primary: Color(0xFF7C4DFF), secondary: Color(0xFFEA80FC), accent: Color(0xFF40C4FF)),
    PetDef(id: 'pet_26', levelRequired: 26, name: 'Tartaruga Cósmica', description: 'Um pequeno mundo flutuando entre estrelas.', species: PetSpecies.turtle, primary: Color(0xFF26A69A), secondary: Color(0xFFA5D6A7), accent: Color(0xFFB2FF59)),
    PetDef(id: 'pet_27', levelRequired: 27, name: 'Corvo Arcano', description: 'Um mensageiro negro com olhos de energia.', species: PetSpecies.raven, primary: Color(0xFF455A64), secondary: Color(0xFFB39DDB), accent: Color(0xFFEA80FC)),
    PetDef(id: 'pet_28', levelRequired: 28, name: 'Mamute Ancestral', description: 'Força pré-histórica envolta em gelo e luz.', species: PetSpecies.mammoth, primary: Color(0xFF8D6E63), secondary: Color(0xFFD7CCC8), accent: Color(0xFF80DEEA)),
    PetDef(id: 'pet_29', levelRequired: 29, name: 'Cão Celestial', description: 'Um guardião luminoso que acompanha seu dono.', species: PetSpecies.celestialHound, primary: Color(0xFFFFB74D), secondary: Color(0xFFFFF3E0), accent: Color(0xFFFF6B00)),
    PetDef(id: 'pet_30', levelRequired: 30, name: 'Dragão Cósmico', description: 'Uma criatura estelar envolta em aurora e fogo.', species: PetSpecies.cosmicDragon, primary: Color(0xFFFF6B00), secondary: Color(0xFF80D8FF), accent: Color(0xFFE040FB)),
  ];

  static PetDef? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final pet in all) {
      if (pet.id == id) return pet;
    }
    return null;
  }

  static PetDef fallbackForLevel(int level) {
    final safe = level.clamp(1, all.length);
    return all[safe - 1];
  }
}