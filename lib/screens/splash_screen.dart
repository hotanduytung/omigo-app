import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.9, curve: Curves.easeOutBack),
    );
    
    _controller.forward();
    
    // Navigate after 2.5 seconds for a smooth display
    _timer = Timer(const Duration(milliseconds: 2500), _navigateNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _navigateNext() {
    if (!mounted) return;
    final state = Provider.of<AppState>(context, listen: false);
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            state.isLoggedIn ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // ── Premium Emerald Gradient Background ──
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF035343), // Deep premium forest emerald
                  Color(0xFF099C7E), // Brand green emerald
                  Color(0xFF0CC6A1), // Lighter vibrant mint/emerald
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          
          // ── Floating Decorative Background Rings ──
          Positioned(
            top: -size.height * 0.1,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 32,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.15,
            left: -size.width * 0.25,
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.03),
                  width: 48,
                ),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.3,
            left: -size.width * 0.4,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.02),
                  width: 20,
                ),
              ),
            ),
          ),
          
          // ── Coordinated scale and fade entry animations ──
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Stylized car logo icon inside container
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: OmigoLogoWidget(
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Wordmark
                    const Text(
                      'OMIGO',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Subtitle
                    Text(
                      'Super App di chuyển miền Trung',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.5,
                      ),
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
