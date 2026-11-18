import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'ingredient_model.dart';
import 'recipe_model.dart';
import 'recipe_service.dart';
import 'utensil.dart';

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipeToEdit;

  const RecipeFormScreen({
    super.key,
    this.recipeToEdit,
  });

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final RecipeService _recipeService = RecipeService();

  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _yieldController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ovenTempController;

  final Set<String> _selectedUtensilIds = {};
  final List<_IngredientRow> _ingredientRows = [];
  final List<_StepGroupBuilder> _stepGroups = [];

  bool _ovenRequired = false;
  bool _isRestricted = false;
  bool _isApproved = false;
  bool _isSaving = false;

  bool get _isEditing => widget.recipeToEdit != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipeToEdit;

    _titleController = TextEditingController(text: r?.title ?? '');
    _categoryController = TextEditingController(text: r?.category ?? '');
    _prepTimeController = TextEditingController(
      text: r != null ? r.prepTimeMinutes.toString() : '',
    );
    _yieldController = TextEditingController(text: r?.yieldPortions ?? '');
    _descriptionController = TextEditingController(text: r?.description ?? '');
    _ovenRequired = r?.ovenRequired ?? false;
    _ovenTempController = TextEditingController(
      text: r?.ovenTemperature != null ? r!.ovenTemperature.toString() : '',
    );
    _isRestricted = r?.isRestricted ?? false;
    _isApproved = r?.isApproved ?? false;

    if (r != null) {
      _selectedUtensilIds.addAll(r.requiredUtensils);

      for (final ing in r.ingredients) {
        _ingredientRows.add(_IngredientRow(
          name: ing.name,
          amount: ing.amount,
          unit: ing.unit,
        ));
      }

      for (final group in r.stepGroups) {
        final groupBuilder = _StepGroupBuilder(title: group.title);
        for (final step in group.steps) {
          groupBuilder.stepControllers.add(TextEditingController(text: step));
        }
        _stepGroups.add(groupBuilder);
      }
    }

    if (_ingredientRows.isEmpty) {
      _ingredientRows.add(_IngredientRow());
    }

    if (_stepGroups.isEmpty) {
      final initialGroup = _StepGroupBuilder(title: 'Modo de Preparo');
      initialGroup.stepControllers.add(TextEditingController());
      _stepGroups.add(initialGroup);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _prepTimeController.dispose();
    _yieldController.dispose();
    _descriptionController.dispose();
    _ovenTempController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final group in _stepGroups) {
      group.dispose();
    }
    super.dispose();
  }

  void _addStepGroup() {
    setState(() {
      final newGroup = _StepGroupBuilder(title: 'Nova Etapa');
      newGroup.stepControllers.add(TextEditingController());
      _stepGroups.add(newGroup);
    });
  }

  void _removeStepGroup(int index) {
    if (_stepGroups.length > 1) {
      setState(() {
        final removed = _stepGroups.removeAt(index);
        removed.dispose();
      });
    }
  }

  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final ingredients = _ingredientRows.map((row) {
        return Ingredient(
          name: row.nameController.text.trim(),
          amount: row.amountController.text.trim(),
          unit: row.unitController.text.trim(),
        );
      }).toList();

      final stepGroups = _stepGroups.map((g) {
        final steps = g.stepControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();

        return RecipeStepGroup(
          title: g.titleController.text.trim().isEmpty
              ? 'Preparo'
              : g.titleController.text.trim(),
          steps: steps,
        );
      }).where((g) => g.steps.isNotEmpty).toList();

      final ovenTemperature = _ovenRequired
          ? int.tryParse(_ovenTempController.text.trim())
          : null;

      final recipeData = Recipe(
        id: widget.recipeToEdit?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()) ?? 0,
        yieldPortions: _yieldController.text.trim(),
        ovenRequired: _ovenRequired,
        ovenTemperature: ovenTemperature,
        requiredUtensils: _selectedUtensilIds.toList(),
        ingredients: ingredients,
        stepGroups: stepGroups,
        isRestricted: _isRestricted,
        isApproved: _isApproved,
        createdAt: widget.recipeToEdit?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await _recipeService.updateRecipe(recipeData);
      } else {
        await _recipeService.addRecipe(recipeData);
      }

      if (mounted) {
        Navigator.pop(context, recipeData);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar receita.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Receita' : 'Nova Receita',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Informações Básicas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título da Receita'),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Informe o título' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      hintText: 'Ex: Confeitaria, Massas',
                    ),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe a categoria' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tempo (minutos)',
                      hintText: 'Ex: 45',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yieldController,
              decoration: const InputDecoration(
                labelText: 'Rendimento',
                hintText: 'Ex: 12 porções, 1 bolo médio',
              ),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Informe o rendimento' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
            const SizedBox(height: 16),

            // Oven settings block
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text(
                      'Necessita de Forno?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Marque se a receita exigir assar em forno pré-aquecido',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    value: _ovenRequired,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _ovenRequired = val ?? false;
                        if (!_ovenRequired) {
                          _ovenTempController.clear();
                        }
                      });
                    },
                  ),
                  if (_ovenRequired)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: TextFormField(
                        controller: _ovenTempController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Temperatura do Forno (°C)',
                          hintText: 'Ex: 180, 200, 220',
                          suffixText: '°C',
                          prefixIcon: Icon(Icons.thermostat_outlined),
                        ),
                        validator: (v) {
                          if (_ovenRequired && (v == null || v.trim().isEmpty)) {
                            return 'Informe a temperatura em °C';
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _isRestricted ? AppColors.primaryTint : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRestricted ? AppColors.primary : AppColors.border,
                ),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Receita Restrita',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Apenas usuários autorizados explicitamente poderão visualizá-la',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _isRestricted,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setState(() => _isRestricted = val),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _isApproved ? const Color(0xFFE8F3EE) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isApproved ? const Color(0xFFB7D9C9) : AppColors.border,
                ),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Receita Testada e Aprovada',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Exibe o selo editorial indicando que você já preparou e aprovou',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _isApproved,
                activeThumbColor: const Color(0xFF2E6F56),
                onChanged: (val) => setState(() => _isApproved = val),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Utensílios Necessários',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Utensil.values.map((utensil) {
                final isSelected = _selectedUtensilIds.contains(utensil.id);
                return FilterChip(
                  avatar: utensil.buildIcon(
                    size: 16,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  label: Text(utensil.label),
                  selected: isSelected,
                  selectedColor: AppColors.primaryTint,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedUtensilIds.add(utensil.id);
                      } else {
                        _selectedUtensilIds.remove(utensil.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ingredientes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _ingredientRows.add(_IngredientRow())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._ingredientRows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: row.nameController,
                        decoration: const InputDecoration(hintText: 'Ingrediente'),
                        validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nome' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.amountController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          hintText: 'Qtd / a gosto',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.unitController,
                        decoration: const InputDecoration(
                          hintText: 'Unid (opc.)',
                        ),
                      ),
                    ),
                    if (_ingredientRows.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            final removed = _ingredientRows.removeAt(index);
                            removed.dispose();
                          });
                        },
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Etapas de Preparo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addStepGroup,
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('Nova Seção'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._stepGroups.asMap().entries.map((groupEntry) {
              final groupIndex = groupEntry.key;
              final group = groupEntry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: group.titleController,
                              decoration: const InputDecoration(
                                labelText: 'Nome da Etapa / Seção',
                                hintText: 'Ex: Massa, Calda, Montagem',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Informe o nome da seção'
                                  : null,
                            ),
                          ),
                          if (_stepGroups.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _removeStepGroup(groupIndex),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...group.stepControllers.asMap().entries.map((stepEntry) {
                        final stepIndex = stepEntry.key;
                        final controller = stepEntry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 14, right: 8),
                                child: Text(
                                  '${stepIndex + 1}.',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: controller,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    hintText: 'Descreva este passo...',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Informe o passo'
                                      : null,
                                ),
                              ),
                              if (group.stepControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      final r = group.stepControllers.removeAt(stepIndex);
                                      r.dispose();
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              group.stepControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Adicionar Passo nesta Seção'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitRecipe,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isEditing ? 'Atualizar Receita' : 'Salvar Receita',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController unitController;

  _IngredientRow({String? name, String? amount, String? unit})
      : nameController = TextEditingController(text: name ?? ''),
        amountController = TextEditingController(text: amount ?? ''),
        unitController = TextEditingController(text: unit ?? '');

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
  }
}

class _StepGroupBuilder {
  final TextEditingController titleController;
  final List<TextEditingController> stepControllers = [];

  _StepGroupBuilder({required String title})
      : titleController = TextEditingController(text: title);

  void dispose() {
    titleController.dispose();
    for (final c in stepControllers) {
      c.dispose();
    }
  }
}