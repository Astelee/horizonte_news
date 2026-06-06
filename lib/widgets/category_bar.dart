import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class CategoryBar extends StatelessWidget {
  const CategoryBar({Key? key}) : super(key: key);

  // Lista de Categorias oficiais do Horizonte News
  static const List<String> _categories = [
    'Horizonte',
    'Ceará',
    'Brasil',
    'Política',
    'Polícia',
    'Esportes',
    'Entretenimento',
  ];

  @override
  Widget build(BuildContext context) {
    // Definindo as cores com base no tema atual para garantir legibilidade
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              label: Text(category),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                // Aqui está a correção: usa a cor do texto do tema atual
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              backgroundColor: isDark 
                  ? AppColors.surfaceDark 
                  : AppColors.surfaceLight,
              side: BorderSide(
                color: isDark 
                    ? AppColors.borderDark 
                    : AppColors.borderLight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.category,
                  arguments: category,
                );
              },
            ),
          );
        },
      ),
    );
  }
}