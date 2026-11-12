import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../../core/app_theme.dart';
import 'recipe_model.dart';
import 'recipe_service.dart';
import 'recipe_detail_screen.dart';
import 'utensil.dart';
import 'recipe_form_screen.dart';
import '../auth/access_token_model.dart';
import '../admin/admin_tokens_screen.dart';
import '../auth/auth_service.dart';
import '../auth/access_gate_screen.dart';

class RecipeListScreen extends StatefulWidget {
  final AccessToken accessToken;
  final bool hasReturnRef;

  const RecipeListScreen({
    super.key,
    required this.accessToken,
    this.hasReturnRef = false,
  });

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final AuthService _authService = AuthService();

  final RecipeService _recipeService = RecipeService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedIngredients = {};
  final Set<Utensil> _selectedUtensils = {};
  bool _onlyRestricted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Dynamically aggregate unique categories across persisted recipes
  List<String> _extractDynamicCategories(List<Recipe> recipes) {
    final categoriesSet = <String>{};
    for (final recipe in recipes) {
      if (recipe.category.trim().isNotEmpty) {
        categoriesSet.add(recipe.category.trim());
      }
    }
    return categoriesSet.toList()..sort((a, b) => a.compareTo(b));
  }

  // Dynamically aggregate unique ingredient names across persisted recipes
  List<String> _extractDynamicIngredients(List<Recipe> recipes) {
    final ingredientsSet = <String>{};
    for (final recipe in recipes) {
      for (final ing in recipe.ingredients) {
        if (ing.name.trim().isNotEmpty) {
          ingredientsSet.add(ing.name.trim());
        }
      }
    }
    return ingredientsSet.toList()..sort((a, b) => a.compareTo(b));
  }

  // Filter recipes based on nominal title search, category, ingredients, and utensils
  List<Recipe> _filterRecipes(List<Recipe> recipes) {
    return recipes.where((recipe) {
      // 0. Privacy check: restricted recipes require explicit grant
      if (recipe.isRestricted &&
          !widget.accessToken.isAdmin &&
          !widget.accessToken.grantedRecipeIds.contains(recipe.id)) {
        return false;
      }

      // 0.1 View filter: toggle to isolate restricted recipes (admin feature)
      if (_onlyRestricted && !recipe.isRestricted) {
        return false;
      }

      // 1. Search by title
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty || recipe.title.toLowerCase().contains(query);

      // 2. Category filter
      final matchesCategory = _selectedCategories.isEmpty ||
          _selectedCategories.contains(recipe.category.trim());

      // 3. Ingredients filter (recipe must contain all selected ingredients)
      final matchesIngredients = _selectedIngredients.isEmpty ||
          _selectedIngredients.every(
                (selectedIng) => recipe.ingredients.any(
                  (i) => i.name.toLowerCase().trim() == selectedIng.toLowerCase().trim(),
            ),
          );

      // 4. Utensils filter (recipe must NOT require any of the selected utensils)
      final selectedUtensilIds = _selectedUtensils.map((u) => u.id).toSet();
      final matchesUtensils = _selectedUtensils.isEmpty ||
          recipe.requiredUtensils.toSet().intersection(selectedUtensilIds).isEmpty;

      return matchesSearch && matchesCategory && matchesIngredients && matchesUtensils;
    }).toList();
  }

  // Open modal bottom sheet for category multi-selection
  void _openCategoryFilter(List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtrar por Categoria',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_selectedCategories.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setModalState(() => _selectedCategories.clear());
                                setState(() {});
                              },
                              child: const Text('Limpar'),
                            ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final isChecked = _selectedCategories.contains(category);

                            return CheckboxListTile(
                              title: Text(category),
                              value: isChecked,
                              activeColor: AppColors.primary,
                              controlAffinity: ListTileControlAffinity.trailing,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Open modal bottom sheet for ingredient multi-selection
  void _openIngredientFilter(List<String> ingredients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtrar por Ingredientes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_selectedIngredients.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setModalState(() => _selectedIngredients.clear());
                                setState(() {});
                              },
                              child: const Text('Limpar'),
                            ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: ingredients.length,
                          itemBuilder: (context, index) {
                            final ingredient = ingredients[index];
                            final isChecked = _selectedIngredients.contains(ingredient);

                            return CheckboxListTile(
                              title: Text(ingredient),
                              value: isChecked,
                              activeColor: AppColors.primary,
                              controlAffinity: ListTileControlAffinity.trailing,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    _selectedIngredients.add(ingredient);
                                  } else {
                                    _selectedIngredients.remove(ingredient);
                                  }
                                });
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Open modal bottom sheet for utensil multi-selection
  void _openUtensilFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Utensílios desnecessários',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_selectedUtensils.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setModalState(() => _selectedUtensils.clear());
                                setState(() {});
                              },
                              child: const Text('Limpar'),
                            ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: Utensil.values.length,
                          itemBuilder: (context, index) {
                            final utensil = Utensil.values[index];
                            final isChecked = _selectedUtensils.contains(utensil);

                            return CheckboxListTile(
                              secondary: utensil.buildIcon(
                                size: 22,
                                color: isChecked
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              title: Text(utensil.label),
                              value: isChecked,
                              activeColor: AppColors.primary,
                              controlAffinity: ListTileControlAffinity.trailing,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    _selectedUtensils.add(utensil);
                                  } else {
                                    _selectedUtensils.remove(utensil);
                                  }
                                });
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Retrieves optional return target URL injected at compile time
  static const String _returnHost = String.fromEnvironment('RETURN_URL');

  void _handleReturnToOrigin() {
    if (kIsWeb) {
      try {
       if (_returnHost.isNotEmpty) {
         web.window.location.href = _returnHost;
       } else {
         // Standard browser history pop: returns to caller tab without hardcoding origins
         web.window.history.back();
       }
      } catch (_) {
        // fallback
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LivCipes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
          leading: widget.hasReturnRef
              ? IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Voltar',
            onPressed: _handleReturnToOrigin,
          )
              : null,
        actions: [
          if (widget.accessToken.isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Gerenciamento de Contas',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminTokensScreen(),
                    )
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AccessGateScreen(),
                    ),
                    (route) => false,
                );
              }
            },
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RecipeFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Recipe>>(
        stream: _recipeService.getRecipesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Erro ao carregar receitas.'),
            );
          }

          final allRecipes = snapshot.data ?? [];
          final dynamicCategories = _extractDynamicCategories(allRecipes);
          final dynamicIngredients = _extractDynamicIngredients(allRecipes);
          final filteredRecipes = _filterRecipes(allRecipes);
          final hasActiveFilters = _selectedCategories.isNotEmpty ||
              _selectedIngredients.isNotEmpty ||
              _selectedUtensils.isNotEmpty;

          return Column(
            children: [
              // Nominal search field for recipe titles
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar receita...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                  ),
                ),
              ),

              // Filter triggers and reset controls
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    // Restricted recipes filter (visible to admin)
                    if (widget.accessToken.isAdmin) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _onlyRestricted = !_onlyRestricted);
                        },
                        icon: Icon(
                          _onlyRestricted ? Icons.lock_rounded : Icons.lock_outline_rounded,
                          size: 16,
                          color: _onlyRestricted ? AppColors.primary : AppColors.textSecondary,
                        ),
                        label: Text(
                          'Restritas',
                          style: TextStyle(
                            color: _onlyRestricted ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: _onlyRestricted ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _onlyRestricted ? AppColors.primaryTint : AppColors.surface,
                          side: BorderSide(
                            color: _onlyRestricted ? AppColors.primary : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Category modal trigger
                    OutlinedButton.icon(
                      onPressed: () => _openCategoryFilter(dynamicCategories),
                      icon: Icon(
                        Icons.category_outlined,
                        size: 16,
                        color: _selectedCategories.isNotEmpty
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      label: Text(
                        _selectedCategories.isEmpty
                            ? 'Categoria'
                            : 'Categoria (${_selectedCategories.length})',
                        style: TextStyle(
                          color: _selectedCategories.isNotEmpty
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: _selectedCategories.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _selectedCategories.isNotEmpty
                            ? AppColors.primaryTint
                            : AppColors.surface,
                        side: BorderSide(
                          color: _selectedCategories.isNotEmpty
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Ingredient modal trigger
                    OutlinedButton.icon(
                      onPressed: () => _openIngredientFilter(dynamicIngredients),
                      icon: Icon(
                        Icons.egg_alt_outlined,
                        size: 16,
                        color: _selectedIngredients.isNotEmpty
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      label: Text(
                        _selectedIngredients.isEmpty
                            ? 'Ingredientes'
                            : 'Ingredientes (${_selectedIngredients.length})',
                        style: TextStyle(
                          color: _selectedIngredients.isNotEmpty
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: _selectedIngredients.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _selectedIngredients.isNotEmpty
                            ? AppColors.primaryTint
                            : AppColors.surface,
                        side: BorderSide(
                          color: _selectedIngredients.isNotEmpty
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Utensil modal trigger
                    OutlinedButton.icon(
                      onPressed: _openUtensilFilter,
                      icon: Icon(
                        Icons.kitchen_outlined,
                        size: 16,
                        color: _selectedUtensils.isNotEmpty
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      label: Text(
                        _selectedUtensils.isEmpty
                            ? 'Utensílios desnecessários'
                            : 'Utensílios desnecessários (${_selectedUtensils.length})',
                        style: TextStyle(
                          color: _selectedUtensils.isNotEmpty
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: _selectedUtensils.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _selectedUtensils.isNotEmpty
                            ? AppColors.primaryTint
                            : AppColors.surface,
                        side: BorderSide(
                          color: _selectedUtensils.isNotEmpty
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // Reset active filters
                    if (hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Limpar todos os filtros',
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 20),
                        color: AppColors.primary,
                        onPressed: () {
                          setState(() {
                            _selectedCategories.clear();
                            _selectedIngredients.clear();
                            _selectedUtensils.clear();
                            _onlyRestricted = false;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 12),

              // Filtered list view
              Expanded(
                child: filteredRecipes.isEmpty
                    ? Center(
                  child: Text(
                    allRecipes.isEmpty
                        ? 'Nenhuma receita cadastrada ainda.'
                        : 'Nenhuma receita encontrada com esses filtros.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRecipes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildRecipeCard(filteredRecipes[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(
                recipe: recipe,
                accessToken: widget.accessToken,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipe.isApproved) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3EE),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFB7D9C9)),
                  ),
                  child: const Text(
                    '★ RECEITA TESTADA E APROVADA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF2E6F56),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  if (recipe.isRestricted && widget.accessToken.isAdmin) ...[
                    const SizedBox(width: 8),
                    const Tooltip(
                      message: 'Receita Restrita',
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    )
                  ],

                  const SizedBox(width: 8),

                  Text(
                    recipe.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe.prepTimeMinutes} min',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.pie_chart_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    recipe.yieldPortions,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (recipe.requiredUtensils.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: recipe.requiredUtensils.map((utensilId) {
                    final utensil = Utensil.fromId(utensilId);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (utensil != null) ...[
                            utensil.buildIcon(size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            utensil?.label ?? utensilId,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}