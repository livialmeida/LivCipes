class Ingredient {
  final String name;
  final double amount;
  final String unit;

  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
        name: map['name'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        unit: map['unit'] as String? ?? '',
    );
  }
}