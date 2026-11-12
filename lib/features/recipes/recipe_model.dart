import 'package:cloud_firestore/cloud_firestore.dart';
import 'ingredient_model.dart';

// Represents a grouped preparation section (e.g., "Cake Batter", "Frosting")
class RecipeStepGroup {
  final String title;
  final List<String> steps;

  const RecipeStepGroup({
    required this.title,
    required this.steps,
  });

  factory RecipeStepGroup.fromMap(Map<String, dynamic> map) {
    final rawSteps = map['steps'];
    final List<String> stepsList = [];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item != null && item.toString().trim().isNotEmpty) {
          stepsList.add(item.toString().trim());
        }
      }
    }

    return RecipeStepGroup(
      title: map['title']?.toString() ?? '',
      steps: stepsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'steps': steps,
    };
  }
}

class Recipe {
  final String id;
  final String title;
  final String? description;
  final String category;
  final int prepTimeMinutes;
  final String yieldPortions;
  final bool ovenRequired;
  final int? ovenTemperature;
  final List<String> requiredUtensils;
  final List<Ingredient> ingredients;
  final List<RecipeStepGroup> stepGroups;
  final bool isRestricted;
  final bool isApproved;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.prepTimeMinutes,
    required this.yieldPortions,
    this.ovenRequired = false,
    this.ovenTemperature,
    required this.requiredUtensils,
    required this.ingredients,
    required this.stepGroups,
    this.isRestricted = false,
    this.isApproved = false,
    required this.createdAt,
  });

  factory Recipe.fromMap(Map<String, dynamic> data, String documentId) {
    List<RecipeStepGroup> parseStepGroups() {
      final rawGroups = data['stepGroups'];
      if (rawGroups is List && rawGroups.isNotEmpty) {
        return rawGroups
            .map((item) => RecipeStepGroup.fromMap(item as Map<String, dynamic>))
            .toList();
      }

      final legacySteps = data['steps'];
      if (legacySteps is List && legacySteps.isNotEmpty) {
        return [
          RecipeStepGroup(
            title: 'Preparo Geral',
            steps: legacySteps.map((s) => s.toString()).toList(),
          ),
        ];
      }

      return [];
    }

    return Recipe(
      id: documentId,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString(),
      category: data['category']?.toString() ?? 'Geral',
      prepTimeMinutes: (data['prepTimeMinutes'] as num?)?.toInt() ?? 0,
      yieldPortions: data['yieldPortions']?.toString() ?? '',
      ovenRequired: data['ovenRequired'] as bool? ?? false,
      ovenTemperature: (data['ovenTemperature'] as num?)?.toInt(),
      requiredUtensils: List<String>.from(data['requiredUtensils'] ?? const []),
      ingredients: (data['ingredients'] as List<dynamic>? ?? const [])
          .map((item) => Ingredient.fromMap(item as Map<String, dynamic>))
          .toList(),
      stepGroups: parseStepGroups(),
      isRestricted: data['isRestricted'] as bool? ?? false,
      isApproved: data['isApproved'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'prepTimeMinutes': prepTimeMinutes,
      'yieldPortions': yieldPortions,
      'ovenRequired': ovenRequired,
      'ovenTemperature': ovenTemperature,
      'requiredUtensils': requiredUtensils,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'stepGroups': stepGroups.map((g) => g.toMap()).toList(),
      'isRestricted': isRestricted,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}