import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/pet_config.dart';
import '../providers/user_xp_provider.dart';
import '../widgets/pet_painters.dart';

class PetScreen extends StatelessWidget {
  const PetScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PET',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'Seu companheiro luminoso',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Consumer<UserXpProvider>(
        builder: (context, xp, _) {
          final level = xp.data.level.clamp(1, PetCatalog.all.length);
          final equippedId = xp.data.equippedPetId ??
              PetCatalog.fallbackForLevel(level).id;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _PetHero(
                  level: level,
                  equippedId: equippedId,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pet = PetCatalog.all[index];
                      final unlocked = pet.levelRequired <= level;
                      final equipped = pet.id == equippedId;
                      return _PetCard(
                        pet: pet,
                        unlocked: unlocked,
                        equipped: equipped,
                        onTap: unlocked
                            ? () => _openPet(context, pet, xp)
                            : null,
                      );
                    },
                    childCount: PetCatalog.all.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPet(
    BuildContext context,
    PetDef pet,
    UserXpProvider xp,
  ) async {
    final equipped = xp.data.equippedPetId == pet.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PetDetailSheet(pet: pet, equipped: equipped),
    );

    if (action == 'equip' && context.mounted) {
      await xp.setEquippedPet(pet.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pet.name} foi equipado.'),
            backgroundColor: const Color(0xFF151515),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _PetHero extends StatelessWidget {
  final int level;
  final String equippedId;

  const _PetHero({required this.level, required this.equippedId});

  @override
  Widget build(BuildContext context) {
    final pet = PetCatalog.byId(equippedId) ?? PetCatalog.fallbackForLevel(level);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            pet.primary.withOpacity(.15),
            const Color(0xFF080808),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: pet.primary.withOpacity(.28)),
        boxShadow: [
          BoxShadow(
            color: pet.primary.withOpacity(.10),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: PetDisplay(pet: pet, size: 92),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PET EQUIPADO',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  pet.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nível atual: $level  •  ${PetCatalog.all.where((p) => p.levelRequired <= level).length}/30 desbloqueados',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final PetDef pet;
  final bool unlocked;
  final bool equipped;
  final VoidCallback? onTap;

  const _PetCard({
    required this.pet,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A0A0A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: equipped
                  ? pet.primary.withOpacity(.65)
                  : const Color(0xFF1C1C1C),
            ),
            boxShadow: equipped
                ? [BoxShadow(color: pet.primary.withOpacity(.12), blurRadius: 16)]
                : null,
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: PetDisplay(
                    pet: pet,
                    size: 92,
                    dimmed: !unlocked,
                  ),
                ),
              ),
              Text(
                pet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white30,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              if (unlocked)
                Text(
                  equipped ? 'EQUIPADO' : 'NÍVEL ${pet.levelRequired}',
                  style: TextStyle(
                    color: equipped ? pet.primary : Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded, color: Colors.white30, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'NÍVEL ${pet.levelRequired}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetDetailSheet extends StatelessWidget {
  final PetDef pet;
  final bool equipped;

  const _PetDetailSheet({required this.pet, required this.equipped});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF222222))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 180, height: 180, child: PetDisplay(pet: pet, size: 180)),
          Text(
            pet.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Desbloqueado no nível ${pet.levelRequired}',
            style: TextStyle(color: pet.primary, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            pet.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: equipped ? () => Navigator.pop(context) : () => Navigator.pop(context, 'equip'),
              icon: Icon(equipped ? Icons.check_circle_rounded : Icons.pets_rounded),
              label: Text(equipped ? 'EQUIPADO' : 'EQUIPAR PET'),
              style: FilledButton.styleFrom(
                backgroundColor: equipped ? const Color(0xFF242424) : AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}