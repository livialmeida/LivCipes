class SpecialCategory {
  final String name;
  final String assetPath;

  const SpecialCategory({
    required this.name,
    required this.assetPath,
  });

  static const List<SpecialCategory> values = [
    SpecialCategory(
        name: 'Natal',
        assetPath: 'assets/icons/christmas-tree.svg'
    ),
  ];

  static SpecialCategory? fromName(String categoryName) {
    final normalized = categoryName.trim().toLowerCase();
    for (final special in values) {
      if (special.name.toLowerCase() == normalized) {
        return special;
      }
    }
    return null;
  }
}