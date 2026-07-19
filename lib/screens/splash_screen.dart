import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';
import '../services/notification_service.dart';
import 'home/main_screen.dart';

/// Branded splash screen shown while the app initializes.
///
/// Instead of blocking in main() (blank screen until Firebase is ready),
/// the app launches straight into this screen, which:
///   1. Plays a short logo animation,
///   2. Initializes Firebase and notifications in the background,
///   3. Fades into MainScreen when BOTH are done — with a minimum display
///      time so the splash never just "blinks" on fast devices.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs initialization and a minimum splash duration in parallel,
  /// then moves to the main app.
  Future<void> _bootstrap() async {
    await Future.wait([
      _initializeServices(),
      // Minimum time the splash stays visible, so the branding registers
      // instead of flashing past on fast devices.
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _initializeServices() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Anonymous sign-in: gives this install a unique Firebase identity
      // (UID) with no login screen, so each device's inventory can be
      // scoped to its own user. If the user is already signed in (returning
      // launch), Firebase reuses the cached credential — no network needed.
      // Only a brand-new install's FIRST launch requires connectivity here;
      // if that fails offline, we continue and retry on a later launch.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      await NotificationService.init();
    } catch (_) {
      // If initialization fails (e.g. no network on first web load),
      // continue anyway — individual screens surface their own errors,
      // and Firestore's offline persistence covers most cases.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A7D44),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Animated logo mark ─────────────────────────────────────
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco,
                    size: 48,
                    color: Color(0xFF3A7D44),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── App name + tagline ─────────────────────────────────────
            FadeTransition(
              opacity: _fade,
              child: Column(
                children: const [
                  Text(
                    'ShelfSense',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Keep your food fresh',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFFCDE3D2),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // ── Loading indicator ──────────────────────────────────────
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}