import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../auth/access_token_model.dart';
import '../recipes/recipe_model.dart';
import '../recipes/recipe_service.dart';

class AdminTokensScreen extends StatefulWidget {
  const AdminTokensScreen({super.key});

  @override
  State<AdminTokensScreen> createState() => _AdminTokensScreenState();
}

class _AdminTokensScreenState extends State<AdminTokensScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RecipeService _recipeService = RecipeService();
  final GlobalKey<FormState> _createFormKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _isCreating = false;
  String? _creationErrorMessage;
  String? _creationSuccessMessage;

  CollectionReference get _tokensCollection =>
      _firestore.collection('access_tokens');

  @override
  void dispose() {
    _nameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _generateRandomKey() {
    final prefix = _nameController.text.trim().replaceAll(' ', '').toUpperCase();
    final cleanPrefix = prefix.isEmpty
        ? 'TOKEN'
        : (prefix.length > 4 ? prefix.substring(0, 4) : prefix);
    final randomDigits = (1000 + Random().nextInt(9000)).toString();
    _tokenController.text = '$cleanPrefix-$randomDigits';
    if (_createFormKey.currentState != null) {
      _createFormKey.currentState!.validate();
    }
  }

  Future<void> _createToken() async {
    setState(() {
      _creationErrorMessage = null;
      _creationSuccessMessage = null;
    });

    if (!_createFormKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final key = _tokenController.text.trim().toUpperCase();

    setState(() => _isCreating = true);

    try {
      final docRef = _tokensCollection.doc(key);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        setState(() {
          _creationErrorMessage = 'Esta chave de token já existe no banco.';
          _isCreating = false;
        });
        return;
      }

      await docRef.set({
        'holderName': name,
        'isAdmin': false,
        'status': 'active',
        'registeredDeviceId': null,
        'grantedRecipeIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _tokenController.clear();

      setState(() {
        _creationSuccessMessage = 'Token $key criado e disponível para uso.';
        _isCreating = false;
      });
    } catch (_) {
      setState(() {
        _creationErrorMessage = 'Falha ao salvar token. Verifique as permissões de rede.';
        _isCreating = false;
      });
    }
  }

  Future<void> _updateStatus(String tokenId, TokenStatus newStatus) async {
    String statusStr = 'active';
    if (newStatus == TokenStatus.pendingReview) statusStr = 'pending_review';
    if (newStatus == TokenStatus.revoked) statusStr = 'revoked';

    await _tokensCollection.doc(tokenId).update({'status': statusStr});
  }

  Future<void> _resetDevice(String tokenId) async {
    await _tokensCollection.doc(tokenId).update({
      'registeredDeviceId': null,
      'deviceModel': null,
      'registeredDeviceIds': [],
      'deviceModels': [],
      'attemptedDeviceId': null,
      'attemptedDeviceModel': null,
      'status': 'active',
    });
  }

  Future<void> _openRecipePermissionsModal(
      AccessToken token, List<Recipe> restrictedRecipes) async {
    final selectedIds = Set<String>.from(token.grantedRecipeIds);
    String query = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = restrictedRecipes.where((r) {
              return r.title.toLowerCase().contains(query.toLowerCase()) ||
                  r.category.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Permissões',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Usuário: ${token.holderName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar receita...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setModalState(() => query = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                        child: Text(
                          restrictedRecipes.isEmpty
                              ? 'Nenhuma receita restrita cadastrada no app.'
                              : 'Nenhuma receita encontrada para a busca.',
                          style: const TextStyle(
                              color: AppColors.textSecondary),
                        ),
                      )
                          : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final recipe = filtered[i];
                          final isGranted =
                          selectedIds.contains(recipe.id);

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              recipe.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                                '${recipe.category} • ${recipe.prepTimeMinutes} min'),
                            value: isGranted,
                            activeColor: AppColors.primary,
                            onChanged: (bool? val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedIds.add(recipe.id);
                                } else {
                                  selectedIds.remove(recipe.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await _tokensCollection.doc(token.token).update({
                            'grantedRecipeIds': selectedIds.toList(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                          'Salvar (${selectedIds.length} selecionada(s))',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Painel de Controle de Acessos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<Recipe>>(
        stream: _recipeService.getRecipesStream(),
        builder: (context, recipeSnap) {
          final allRecipes = recipeSnap.data ?? [];
          final restrictedRecipes =
          allRecipes.where((r) => r.isRestricted).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _createFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.key, size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Criar novo token de acesso',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Defina o titular e a chave de acesso exclusiva do dispositivo.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            hintText: 'Ex: Gabriela',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Informe o nome da pessoa'
                              : null,
                          onChanged: (_) {
                            if (_tokenController.text.isEmpty) {
                              _generateRandomKey();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tokenController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Chave do Token',
                                  hintText: 'Ex: GABRIELA-1234',
                                  prefixIcon: Icon(Icons.vpn_key_outlined),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Informe ou gere uma chave'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: IconButton(
                                tooltip: 'Gerar Chave Aleatória',
                                icon: const Icon(Icons.casino_outlined,
                                    color: AppColors.primary),
                                onPressed: _generateRandomKey,
                              ),
                            ),
                          ],
                        ),
                        if (_creationErrorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _creationErrorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_creationSuccessMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _creationSuccessMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isCreating ? null : _createToken,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _isCreating
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Cadastrar Token',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Usuários e Dispositivos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Receitas Restritas no App: ${restrictedRecipes.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: _tokensCollection.snapshots(),
                builder: (context, tokenSnap) {
                  if (tokenSnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final docs = tokenSnap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Nenhum usuário cadastrado ainda.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  final tokens = docs
                      .map((d) => AccessToken.fromFirestore(
                      d as DocumentSnapshot<dynamic>))
                      .toList();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tokens.length,
                    separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = tokens[index];
                      final isLocked = t.status == TokenStatus.pendingReview;
                      final isRevoked = t.status == TokenStatus.revoked;

                      Color statusColor = Colors.green;
                      String statusLabel = 'Ativo';
                      if (isLocked) {
                        statusColor = Colors.orange;
                        statusLabel = 'Em Análise';
                      } else if (isRevoked) {
                        statusColor = Colors.red;
                        statusLabel = 'Revogado';
                      }

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            t.holderName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (t.isAdmin) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryTint,
                                                borderRadius:
                                                BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'ADMIN',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      SelectableText(
                                        'Chave: ${t.token}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    t.registeredDeviceId == null
                                        ? Icons.phonelink_erase
                                        : Icons.smartphone,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.registeredDeviceIds.isEmpty && t.registeredDeviceId == null
                                              ? 'Nenhum aparelho vinculado'
                                              : 'Dispositivos (${t.registeredDeviceIds.isEmpty ? 1 : t.registeredDeviceIds.length}/${t.maxDevices}): ${t.deviceModels.isNotEmpty ? t.deviceModels.join(", ") : (t.deviceModel ?? t.registeredDeviceId)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        if (t.attemptedDeviceModel != null || t.attemptedDeviceId != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tentativa bloqueada: ${t.attemptedDeviceModel ?? t.attemptedDeviceId}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.restaurant_menu,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Receitas Nominais Autorizadas: ${t.grantedRecipeIds.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _openRecipePermissionsModal(
                                      t,
                                      restrictedRecipes,
                                    ),
                                    icon: const Icon(Icons.check_box_outlined,
                                        size: 16),
                                    label: const Text('Gerenciar Receitas'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryTint,
                                      foregroundColor: AppColors.primary,
                                      elevation: 0,
                                    ),
                                  ),
                                  if (t.registeredDeviceId != null || t.registeredDeviceIds.isNotEmpty)
                                    OutlinedButton.icon(
                                      onPressed: () => _resetDevice(t.token),
                                      icon: const Icon(Icons.phonelink_erase,
                                          size: 16),
                                      label: const Text('Resetar Aparelho'),
                                    ),
                                  PopupMenuButton<TokenStatus>(
                                    child: const Chip(
                                      label: Text('Status'),
                                      avatar: Icon(Icons.arrow_drop_down,
                                          size: 18),
                                    ),
                                    onSelected: (s) => _updateStatus(t.token, s),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: TokenStatus.active,
                                        child: Text('Ativo'),
                                      ),
                                      const PopupMenuItem(
                                        value: TokenStatus.pendingReview,
                                        child: Text('Em Análise'),
                                      ),
                                      const PopupMenuItem(
                                        value: TokenStatus.revoked,
                                        child: Text('Revogado'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}