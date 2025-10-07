import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  // Toggle mode: true = subtle watermark, false = strong gradient blend
  final bool subtleMode = true;

  double _opacity = 0.0; // initial opacity (invisible)

  @override
  void initState() {
    super.initState();
    // Fade in after a short delay
    Future.delayed(const Duration(milliseconds: 400), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6A11CB),
                  Color(0xFF2575FC),
                ], // purple to blue
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ✅ Lottie background animation (faded)
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: Lottie.asset(
                'assests/syHOSCTz9G (1).json',
                fit: BoxFit.cover,
                repeat: true,
                reverse: false,
                animate: true,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // ✅ Illustration with blending + fade-in animation
                Expanded(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _opacity,
                      duration: const Duration(seconds: 2), // fade duration
                      curve: Curves.easeInOut,
                      child: Image.asset(
                        "assests/studentpic3.jpg",
                        height: 280,
                        color: subtleMode
                            ? Colors.white.withOpacity(0.6) // watermark
                            : Colors.deepPurple.withOpacity(0.4), // blend
                        colorBlendMode: subtleMode
                            ? BlendMode.modulate
                            : BlendMode.overlay,
                      ),
                    ),
                  ),
                ),

                // Title
                AnimatedOpacity(
                  opacity: _opacity,
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeIn,
                  child: Text(
                    "Student Reminder",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black45,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                AnimatedOpacity(
                  opacity: _opacity,
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeIn,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      "Stay on top of assignments, classes, and exams. Your study buddy in one app!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Get Started button
                AnimatedOpacity(
                  opacity: _opacity,
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text(
                        "Get Started",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2575FC),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}