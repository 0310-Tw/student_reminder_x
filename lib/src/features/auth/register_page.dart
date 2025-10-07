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
  bool _googleSignInMode = false; // Track if user chose Google sign-in

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      if (_googleSignInMode) {
        // Complete Google registration with additional info
        await AuthService.instance.registerWithGoogle(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          courseGroup: _group,
          phone: _phone.text.trim(),
        );
      } else {
        // Regular email/password registration
        await AuthService.instance.register(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          courseGroup: _group,
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );
      }
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.main);
    } catch (e) {
      displaySnackBar(context, 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      // Get Google user info and pre-fill the form
      final googleUserInfo = await AuthService.instance.getGoogleUserInfo();

      setState(() {
        _first.text = googleUserInfo['firstName'] ?? '';
        _last.text = googleUserInfo['lastName'] ?? '';
        _email.text = googleUserInfo['email'] ?? '';
        _googleSignInMode = true;
      });

      if (mounted) {
        displaySnackBar(
          context,
          'Google info loaded! Please complete the remaining fields.',
        );
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, 'Google Sign-In Failed: $e');
      }
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
                    // Google Sign-In Button (only show if not in Google mode)
                    if (!_googleSignInMode) ...[
                      Container(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _signInWithGoogle,
                          icon: Icon(
                            Icons.g_mobiledata,
                            color: Color(0xFF4285F4),
                          ),
                          label: Text(
                            'Sign up with Google',
                            style: TextStyle(color: Color(0xFF4285F4)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Color(0xFF4285F4)),
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      SizedBox(height: 16),
                    ],

                    // Show Google mode indicator
                    if (_googleSignInMode) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF4285F4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(0xFF4285F4).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF4285F4)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Google account linked! Complete the remaining fields below.',
                                style: TextStyle(color: Color(0xFF4285F4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _first,
                      decoration: InputDecoration(
                        labelText: 'First name',
                        enabled:
                            !_googleSignInMode, // Disable if pre-filled by Google
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _last,
                      decoration: InputDecoration(
                        labelText: 'Last name',
                        enabled:
                            !_googleSignInMode, // Disable if pre-filled by Google
                      ),
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
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        enabled:
                            !_googleSignInMode, // Disable if pre-filled by Google
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      decoration: InputDecoration(labelText: 'Phone #'),
                    ),
                    SizedBox(height: 12),

                    // Only show password field if not using Google sign-in
                    if (!_googleSignInMode) ...[
                      TextField(
                        controller: _password,
                        decoration: InputDecoration(labelText: 'Password'),
                        obscureText: true,
                      ),
                      SizedBox(height: 12),
                    ],

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
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _googleSignInMode
                                  ? 'Complete Registration'
                                  : 'Create Account',
                            ),
                    ),

                    // Reset option for Google sign-in mode
                    if (_googleSignInMode) ...[
                      SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _googleSignInMode = false;
                            _first.clear();
                            _last.clear();
                            _email.clear();
                          });
                        },
                        child: Text('Use email registration instead'),
                      ),
                    ],
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
