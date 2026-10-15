import 'package:attendance_app/login.dart';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _baseColor = const Color.fromARGB(255, 12, 86, 147);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Fingerprint scan loop (bottom -> top), repeats until we navigate away.
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  // One-shot intro (fade + slide of the texts, scale of the icon card).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  @override
  void dispose() {
    _scan.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    Widget nextScreen = LoginScreen();

    if (ApiService.authToken != null && ApiService.employeeId != null) {
      try {
        final response = await ApiService.getEmployeeById();

        if (response != null) {
          nextScreen = HomeScreen();
        }
      } catch (_) {
        // Network/API failure: fall back to the login screen.
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));
    final pop = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _baseColor,
                _baseColor.withOpacity(0.72),
                Colors.blue.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Soft decorative circles
              Positioned(
                top: -80,
                right: -60,
                child: _blob(240, 0.07),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: _blob(300, 0.06),
              ),

              Positioned.fill(
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),

                    // ---------- Fingerprint scanner ----------
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1).animate(pop),
                      child: FadeTransition(
                        opacity: fade,
                        child: _FingerprintScanner(animation: _scan),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ---------- Title ----------
                    FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: slide,
                        child: Column(
                          children: [
                            const Text(
                              'Attendance System',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Track time. Manage tasks. Stay on schedule.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 4),

                    // ---------- Footer ----------
                    FadeTransition(
                      opacity: fade,
                      child: Column(
                        children: [
                          _LoadingDots(animation: _scan),
                          const SizedBox(height: 10),
                          Text(
                            'Verifying your session',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

// ====================================================================
// Fingerprint with bottom -> top scan/fill + reflection edge
// ====================================================================

class _FingerprintScanner extends StatelessWidget {
  final Animation<double> animation;

  const _FingerprintScanner({required this.animation});

  static const double _card = 168;
  static const double _icon = 104;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Ease so the sweep accelerates gently, then a short pause at the top.
        final raw = animation.value;
        final t = Curves.easeInOut.transform((raw / 0.85).clamp(0.0, 1.0));
        final glowOpacity = raw < 0.85 ? 1.0 : (1 - (raw - 0.85) / 0.15);

        return SizedBox(
          width: _card + 40,
          height: _card + 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding pulse ring
              _ring(raw, 0.0),
              _ring(raw, 0.5),

              // Glass card
              Container(
                width: _card,
                height: _card,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
              ),

              // Fingerprint
              SizedBox(
                width: _icon,
                height: _icon,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Dim base icon
                    Icon(
                      Icons.verified_user_outlined,
                      size: _icon,
                      color: Colors.white.withOpacity(0.25),
                    ),

                    // Bright icon revealed from bottom to top, with a soft
                    // fading edge (this is the "reflection" sweep).
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) {
                        final edge = (t + 0.14).clamp(0.0, 1.0);
                        return LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0),
                          ],
                          stops: [0, t, edge, 1],
                        ).createShader(rect);
                      },
                      child: const Icon(
                        Icons.verified_user,
                        size: _icon,
                        color: Colors.white,
                      ),
                    ),

                    // Glowing scan line riding the edge
                    Positioned(
                      left: -14,
                      right: -14,
                      top: _icon * (1 - t) - 2,
                      child: Opacity(
                        opacity: glowOpacity.clamp(0.0, 1.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white,
                                Colors.white.withOpacity(0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.85),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(double raw, double offset) {
    final p = (raw + offset) % 1.0;
    return Container(
      width: _card + 40 * p,
      height: _card + 40 * p,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(48 + 20 * p),
        border: Border.all(
          color: Colors.white.withOpacity(0.22 * (1 - p)),
          width: 1.5,
        ),
      ),
    );
  }
}

// ====================================================================
// Three-dot activity indicator (replaces CircularProgressIndicator)
// ====================================================================

class _LoadingDots extends StatelessWidget {
  final Animation<double> animation;

  const _LoadingDots({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (animation.value * 1.5 - i * 0.18) % 1.0;
            final wave = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.35 + 0.65 * wave),
              ),
            );
          }),
        );
      },
    );
  }
}