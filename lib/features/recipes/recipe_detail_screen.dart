import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../auth/access_token_model.dart';
import 'recipe_form_screen.dart';
import 'recipe_model.dart';
import 'recipe_service.dart';
import 'utensil.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final AccessToken accessToken;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.accessToken,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _copiedToClipboard = false;

  late Recipe _currentRecipe;
  final RecipeService _recipeService = RecipeService();

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toString();
  }

  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Receita?'),
        content: Text('Tem certeza que deseja apagar "${_currentRecipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _recipeService.deleteRecipe(_currentRecipe.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _editRecipe() async {
    final updated = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeFormScreen(recipeToEdit: _currentRecipe),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _currentRecipe = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Verify access authorization against recipe restriction rules
    final isAuthorized = !widget.recipe.isRestricted ||
      widget.accessToken.isAdmin ||
      widget.accessToken.grantedRecipeIds.contains(widget.recipe.id);

    // 2. Defensive block: intercept rendering if unauthorized
    if (!isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Acesso Restrito'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Receita Restrita',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sua chave de acesso não possui permissão para visualizar esta receita.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentRecipe.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.accessToken.isAdmin) ...[
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copiedToClipboard ? Icons.check_rounded : Icons.share_outlined,
                  key: ValueKey<bool>(_copiedToClipboard),
                  color: _copiedToClipboard ? AppColors.primary : null,
                ),
              ),
              tooltip: _copiedToClipboard ? 'Copiado' : 'Copiar link da receita',
              onPressed: () async {
                // 1. Build canonical share url using base uri and recipe id query param
               final shareUrl = Uri.base.replace(
                 queryParameters: {
                   'recipe': widget.recipe.id,
                 },
               ).toString();

                // 2. Persis formatted link to system clipboard
                await Clipboard.setData(ClipboardData(text: shareUrl));

                // 3. Guard against asynchronous gap if widget unmounts
                if (!mounted) return;

                // 4. Switch visual indicator to confirm checkmark
                setState(() => _copiedToClipboard = true);

               // 5. Retain confirmation state for 2 secondas
               await Future.delayed(const Duration(seconds: 2));

               // 6. Reset back to original share icon
               if (mounted) {
                 setState(() => _copiedToClipboard = false);
               }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: _editRecipe,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Excluir',
              onPressed: _deleteRecipe,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentRecipe.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${_currentRecipe.prepTimeMinutes} min',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pie_chart_outline, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _currentRecipe.yieldPortions,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (_currentRecipe.ovenRequired && _currentRecipe.ovenTemperature != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thermostat_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(
                            '${_currentRecipe.ovenTemperature}°C',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            if (_currentRecipe.description != null &&
                _currentRecipe.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _currentRecipe.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (_currentRecipe.requiredUtensils.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Utensílios Necessários',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentRecipe.requiredUtensils.map((utensilId) {
                  final utensil = Utensil.fromId(utensilId);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (utensil != null) ...[
                          utensil.buildIcon(size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          utensil?.label ?? utensilId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 28),
            const Text(
              'Ingredientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _currentRecipe.ingredients.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ingredient = _currentRecipe.ingredients[index];
                  final formattedAmount = _formatAmount(ingredient.amount);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$formattedAmount ${ingredient.unit}'.trim(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Modo de Preparo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._currentRecipe.stepGroups.map((group) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.title.isNotEmpty) ...[
                      Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.steps.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final step = group.steps[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryTint,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  step,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}