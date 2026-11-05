import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shell/main_shell.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool isRegister = false;
  bool isSubmitting = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (!isRegister) return null;
    final name = value?.trim() ?? '';
    if (name.isEmpty || name.length < 2 || name.length > 80) {
      return 'Escribe un nombre válido (2 a 80 caracteres).';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!valid || email.length > 120) {
      return 'Escribe un correo válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8 || password.length > 72) {
      return 'La contraseña debe tener entre 8 y 72 caracteres.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    try {
      if (isRegister) {
        await _authService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.bolt, size: 30, color: Colors.white),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      isRegister ? 'Crea tu cuenta' : 'Vuelve a entrenar',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRegister
                          ? 'Empieza a construir tu mejor versión.'
                          : 'Tu progreso, tus rutinas, tu ritmo.',
                      style: const TextStyle(
                        color: AppColors.subtext,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (isRegister) ...[
                      const Text('Nombre'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 80,
                        validator: _validateName,
                        decoration: const InputDecoration(
                          hintText: 'Alex Rivera',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    const Text('Correo electrónico'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 120,
                      validator: _validateEmail,
                      decoration: const InputDecoration(
                        hintText: 'alex@email.com',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Contraseña'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: obscurePassword,
                      maxLength: 72,
                      validator: _validatePassword,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        counterText: '',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.subtext,
                          ),
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: isSubmitting ? null : _submit,
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isRegister ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () => setState(() => isRegister = !isRegister),
                        child: Text(
                          isRegister ? 'Ya tengo una cuenta' : 'Crear una cuenta',
                          style: const TextStyle(color: AppColors.subtext),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
