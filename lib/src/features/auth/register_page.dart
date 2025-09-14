import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/shared/routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _group = 'mobile'; //    'mobile'  |  'web'
  bool _busy = false;

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.register(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        courseGroup: _group,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.main);
    } catch (e) {
      displaySnackBar(context, 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Text('Student Registration'),
      ),
      body: Stack(
        children: [
          // Lottie animation as background
          Positioned.fill(
            child: Lottie.asset(
              'assests/login pic.json',
              fit: BoxFit.cover,
              repeat: true,
              reverse: false,
              animate: true,
            ),
          ),
          // Registration form with semi-transparent background
          Container(
            color: Colors.white.withOpacity(0.85),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _first,
                      decoration: InputDecoration(labelText: 'First name'),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _last,
                      decoration: InputDecoration(labelText: 'Last name'),
                    ),
                    SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'mobile', label: Text('Mobile')),
                        ButtonSegment(value: 'web', label: Text('Web')),
                      ],
                      selected: {_group},
                      onSelectionChanged: (sel) =>
                          setState(() => _group = sel.first),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      decoration: InputDecoration(labelText: 'Email address'),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      decoration: InputDecoration(labelText: 'Phone #'),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      decoration: InputDecoration(labelText: 'Password'),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _busy ? null : _register,
                      child: _busy
                          ? CircularProgressIndicator()
                          : Text('Create Account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
