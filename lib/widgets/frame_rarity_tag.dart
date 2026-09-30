import 'package:flutter/material.dart';
import '../config/pet_config.dart';

/// Tag visual do pet equipado.
///
/// O nome antigo FrameRarityTag é mantido apenas para compatibilidade com
/// telas legadas; não exibe mais raridade de nível.
class PetTag extends StatelessWidget {
  final int level;
  final String? petId;
  final double fontSize;

  const PetTag({
    Key? key,
    required this.level,
    this.petId,
    this.fontSize = 9,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pet = PetCatalog.byId(petId) ?? PetCatalog.fallbackForLevel(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: pet.primary.withOpacity(.10),
        border: Border.all(color: pet.primary.withOpacity(.45)),
      ),
      child: Text(
        pet.name.toUpperCase(),
        style: TextStyle(
          color: pet.primary,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: .7,
        ),
      ),
    );
  }
}

/// Compatibilidade com chamadas existentes.
@Deprecated('Use PetTag')
class FrameRarityTag extends PetTag {
  const FrameRarityTag({
    Key? key,
    required int level,
    String? petId,
    double fontSize = 9,
  }) : super(key: key, level: level, petId: petId, fontSize: fontSize);
}