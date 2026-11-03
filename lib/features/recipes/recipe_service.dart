import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_model.dart';

class RecipeService {
  final FirebaseFirestore _firestore;

  RecipeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection reference using withConverter for strict type safety
  CollectionReference<Recipe> get _recipesCollection =>
      _firestore.collection('recipes').withConverter<Recipe>(
        fromFirestore: (snapshot, _) => Recipe.fromMap(
          snapshot.data() ?? {},
          snapshot.id,
        ),
        toFirestore: (recipe, _) => recipe.toMap(),
      );

  // Stream of all recipes ordered by creation date descending
  Stream<List<Recipe>> getRecipesStream() {
    return _recipesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Create new recipe document in Firestore
  Future<void> addRecipe(Recipe recipe) async {
    await _recipesCollection.add(recipe);
  }

  // Update existing recipe document
  Future<void> updateRecipe(Recipe recipe) async {
    if (recipe.id.isEmpty) return;
    await _recipesCollection.doc(recipe.id).set(recipe);
  }

  // Delete recipe document
  Future<void> deleteRecipe(String recipeId) async {
    if (recipeId.isEmpty) return;
    await _recipesCollection.doc(recipeId).delete();
  }
}