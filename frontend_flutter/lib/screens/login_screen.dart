import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final success = _isLogin
        ? await ApiService.login(_emailController.text, _passwordController.text)
        : await ApiService.register(
            _usernameController.text,
            _emailController.text,
            _passwordController.text,
          );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (_isLogin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Al registrarse exitosamente, cambiar a login
        setState(() {
          _isLogin = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro exitoso. Por favor inicia sesión.')),
        );
      }
    } else {
      setState(() {
        _errorMessage = _isLogin
            ? 'Error de inicio de sesión. Verifica tus credenciales.'
            : 'Error en el registro. Nombre o correo pueden estar tomados.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo de DiviVoice
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/logo.jpg',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 120,
                    height: 120,
                    color: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.music_note, size: 60, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'DiviVoice',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
              ),
              Text(
                'Canta y conéctate al 100%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              if (!_isLogin) ...[
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _isLogin ? 'Nombre de usuario o Correo' : 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: _isLogin ? TextInputType.text : TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isLogin ? 'Iniciar Sesión' : 'Registrarse',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = '';
                  });
                },
                child: Text(
                  _isLogin
                      ? '¿No tienes cuenta? Registrate aquí'
                      : '¿Ya tienes cuenta? Inicia sesión',
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
