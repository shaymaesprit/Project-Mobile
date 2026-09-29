import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final ValueNotifier<bool> _passwordVisible = ValueNotifier<bool>(false);
  bool _isLogin = true;
  final _email = TextEditingController(text: 'maya@studentlife.com');
  final _password = TextEditingController(text: 'Password123!');

  @override
  void dispose() {
    _passwordVisible.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFF006D77),
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    _isLogin ? 'Welcome back' : 'Create account',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _isLogin ? 'Sign in to continue your academic flow' : 'Set up your student profile',
                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 30),
                if (!_isLogin) ...[
                  Row(
                    children: [
                      Expanded(child: _Field(label: 'First name', hint: 'Maya')),
                      const SizedBox(width: 12),
                      Expanded(child: _Field(label: 'Last name', hint: 'Khaled')),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                _Field(label: 'Email', hint: 'name@university.edu', controller: _email),
                const SizedBox(height: 14),
                ValueListenableBuilder<bool>(
                  valueListenable: _passwordVisible,
                  builder: (context, visible, child) {
                    return _Field(
                      label: 'Password',
                      hint: '********',
                      controller: _password,
                      obscureText: !visible,
                      suffixIcon: IconButton(
                        onPressed: () => _passwordVisible.value = !visible,
                        icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                      ),
                    );
                  },
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 14),
                  _Field(label: 'University', hint: 'Cairo University'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _Field(label: 'Academic level', hint: 'Third year')),
                      const SizedBox(width: 12),
                      Expanded(child: _Field(label: 'Specialization', hint: 'Computer Science')),
                    ],
                  ),
                ],
                if (_isLogin) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: widget.onDone,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF006D77),
                  ),
                  child: Text(_isLogin ? 'Login' : 'Register'),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isLogin ? 'Don’t have an account?' : 'Already have an account?'),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin ? 'Sign up' : 'Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
