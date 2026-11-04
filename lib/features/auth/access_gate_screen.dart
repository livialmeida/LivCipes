import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../../core/app_theme.dart';
import '../recipes/recipe_list_screen.dart';
import '../recipes/recipe_model.dart';
import '../recipes/recipe_service.dart';
import '../recipes/recipe_detail_screen.dart';
import 'access_token_model.dart';
import 'auth_service.dart';

class AccessGateScreen extends StatefulWidget {
  const AccessGateScreen({super.key});

  @override
  State<AccessGateScreen> createState() => _AccessGateScreenState();
}

class _AccessGateScreenState extends State<AccessGateScreen> {
  final AuthService _authService = AuthService();
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _tokenController = TextEditingController();

  String? _targetRecipeId;
  bool _isCheckingSession = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  // Sanitizes the browser address bar by stripping query parameters without a page reload
  void _cleanAddressBar() {
    if (kIsWeb) {
      try {
        web.window.history.replaceState(null, '', Uri.base.path);
      } catch (_) {
        // Graceful fallback if history API is restricted in sandbox
      }
    }
  }

  // Check for auto-login session
  Future<void> _bootstrapSession() async {
  // 1. Ensure target recipe ID is captured from the window location
    _targetRecipeId ??= Uri.base.queryParameters['recipe'];

    final token = await _authService.checkCurrentSession();
    if (!mounted) return;

    if (token != null) {
      // Directs to the unified routing method instead of push list screen
      await _handlePostAuthNavigation(token);
    } else {
      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  // Unified post-authentication routing
  Future<void> _handlePostAuthNavigation(AccessToken token) async {
    final recipeId = _targetRecipeId ?? Uri.base.queryParameters['recipe'];

    if (recipeId == null || recipeId.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeListScreen(accessToken: token),
          ),
        );
      }
      return;
    }

    try {
      final Recipe? recipe = await _recipeService.getRecipeById(recipeId);

      if (!mounted) return;

      if (recipe == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeListScreen(accessToken: token),
          ),
        );
        return;
      }

      final hasPermission = !recipe.isRestricted ||
          token.isAdmin ||
          token.grantedRecipeIds.contains(recipe.id);

      if (!hasPermission) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeListScreen(accessToken: token),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeListScreen(accessToken: token),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(
            recipe: recipe,
            accessToken: token,
          ),
        ),
      );

      // Clean query parameter from browser address bar immediately after routing
      _cleanAddressBar();
    } catch (_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeListScreen(accessToken: token),
          ),
        );
      }
    }
  }

  // Manual token validation
  Future<void> _handleTokenSubmission() async {
    final key = _tokenController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Por favor, insira sua chave de acesso.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authService.validateToken(key);

      if (token == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Chave de acesso inválida ou não encontrada.';
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        _navigateToRecipes(token);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToRecipes(AccessToken token) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeListScreen(accessToken: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'LivCipes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Caderno Digital de Receitas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _tokenController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Chave de Acesso',
                    hintText: 'Ex: LIV-2026',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  onSubmitted: (_) => _handleTokenSubmission(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleTokenSubmission,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}