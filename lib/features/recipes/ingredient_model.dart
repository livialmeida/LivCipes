class Ingredient {
  final String name;
  final String amount;
  final String unit;

  const Ingredient({
    required this.name,
    this.amount = '',
    this.unit = '',
});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    String parsedAmount = '';

    if (rawAmount is num) {
      if (rawAmount > 0) {
        parsedAmount = rawAmount == rawAmount.roundToDouble()
            ? rawAmount.toInt().toString()
            : rawAmount.toString();
      }
    } else if (rawAmount is String) {
      parsedAmount = rawAmount;
    }

    return Ingredient(
        name: map['name'] as String? ?? '',
        amount: parsedAmount,
        unit: map['unit'] as String? ?? '',
    );
  }
}