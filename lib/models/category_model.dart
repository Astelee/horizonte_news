class CategoryModel {
  final String name;
  final String slug;

  CategoryModel({
    required this.name,
    required this.slug,
  });

  // Converte uma string de marcador do Blogger em um objeto de categoria estruturado
  factory CategoryModel.fromString(String label) {
    return CategoryModel(
      name: label,
      slug: label.toLowerCase().replaceAll(' ', '-'),
    );
  }
}
