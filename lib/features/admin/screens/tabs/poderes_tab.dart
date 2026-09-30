import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/pet_config.dart';
import '../../../../providers/user_xp_provider.dart';
import '../../../../widgets/app_avatar.dart';
import '../../../../widgets/pet_painters.dart';

/// Vitrine administrativa dos 30 pets e das auras do sistema.
/// Esta aba é somente visualização: selecionar um pet aqui não altera
/// o pet equipado do administrador nem de nenhum usuário.
class PoderesTab extends StatefulWidget {
  const PoderesTab({Key? key}) : super(key: key);

  @override
  State<PoderesTab> createState() => _PoderesTabState();
}

class _PoderesTabState extends State<PoderesTab> {
  int _previewLevel = 1;
  String _previewPetId = PetCatalog.all.first.id;

  @override
  Widget build(BuildContext context) {
    final xpData = context.watch<UserXpProvider>().data;
    final displayName = (xpData.username != null && xpData.username!.trim().isNotEmpty)
        ? xpData.username!
        : 'Você';
    final photoUrl = xpData.photoUrl;
    final previewPet = PetCatalog.byId(_previewPetId) ?? PetCatalog.all.first;

    return Container(
      color: AppColors.backgroundDark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _notice(),
            const SizedBox(height: 22),
            const _SectionLabel(label: 'PREVIEW DO PET', icon: Icons.pets_rounded),
            const SizedBox(height: 12),
            _previewCard(displayName, photoUrl, previewPet),
            const SizedBox(height: 24),
            const _SectionLabel(label: 'SELECIONAR PET', icon: Icons.grid_view_rounded),
            const SizedBox(height: 12),
            _levelSelector(),
            const SizedBox(height: 14),
            _petGrid(),
            const SizedBox(height: 26),
            const _SectionLabel(label: 'AURAS DE NÍVEL', icon: Icons.auto_awesome_rounded),
            const SizedBox(height: 12),
            const _AurasTestList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _notice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.primaryOrange.withOpacity(.06),
          border: Border.all(color: AppColors.primaryOrange.withOpacity(.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.visibility_rounded, color: AppColors.primaryOrange, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Apenas visualização — os 30 pets podem ser conferidos aqui sem alterar dados.',
                style: TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _previewCard(String name, String? photoUrl, PetDef pet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [pet.primary.withOpacity(.14), const Color(0xFF090909)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: pet.primary.withOpacity(.35)),
        boxShadow: [BoxShadow(color: pet.primary.withOpacity(.10), blurRadius: 22)],
      ),
      child: Column(
        children: [
          UserAvatarDisplay(
            name: name,
            photoUrl: photoUrl,
            level: _previewLevel,
            equippedPetId: pet.id,
            size: 92,
            showLevelAura: true,
          ),
          const SizedBox(height: 12),
          Text(pet.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Desbloqueia no nível ${pet.levelRequired}', style: TextStyle(color: pet.primary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(pet.description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _levelSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202020)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nível de preview: $_previewLevel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Text('${PetCatalog.all.where((p) => p.levelRequired <= _previewLevel).length}/30 desbloqueados', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          Slider(
            value: _previewLevel.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            activeColor: AppColors.primaryOrange,
            onChanged: (v) => setState(() => _previewLevel = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _petGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: PetCatalog.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: .82,
      ),
      itemBuilder: (_, index) {
        final pet = PetCatalog.all[index];
        final unlocked = pet.levelRequired <= _previewLevel;
        final selected = pet.id == _previewPetId;
        return GestureDetector(
          onTap: unlocked ? () => setState(() => _previewPetId = pet.id) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF090909),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? pet.primary : const Color(0xFF1B1B1B),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected ? [BoxShadow(color: pet.primary.withOpacity(.18), blurRadius: 12)] : null,
            ),
            child: Column(
              children: [
                Expanded(child: Stack(alignment: Alignment.center, children: [
                  PetDisplay(pet: pet, size: 70, dimmed: !unlocked),
                  if (!unlocked)
                    Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xCC000000)),
                      child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 14),
                    ),
                ])),
                Text(pet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unlocked ? Colors.white : Colors.white30, fontSize: 9.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('Nível ${pet.levelRequired}', style: TextStyle(color: unlocked ? pet.primary : Colors.white24, fontSize: 8, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AurasTestList extends StatelessWidget {
  const _AurasTestList();

  @override
  Widget build(BuildContext context) {
    final xpData = context.watch<UserXpProvider>().data;
    final displayName = (xpData.username != null && xpData.username!.trim().isNotEmpty) ? xpData.username! : 'Você';
    return Column(
      children: List.generate(30, (i) => i + 1).map((level) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1A1A1A))),
          child: Row(
            children: [
              UserAvatarDisplay(name: displayName, level: level, size: 58, showLevelAura: true),
              const SizedBox(width: 14),
              Text('NÍVEL $level', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 14),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.primaryOrange, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryOrange.withOpacity(.4), Colors.transparent])))),
      ],
    );
  }
}