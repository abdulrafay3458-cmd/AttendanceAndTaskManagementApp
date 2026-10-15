import 'package:attendance_app/otp_screen.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

const _kBg = Color(0xFFF5F6FA);
const _kInk = Color(0xFF1F2430);
const _kMuted = Color(0xFF7A8194);
const _kLine = Color(0xFFE6E8F0);
const _kGreen = Color(0xFF22A06B);
const _kRed = Color(0xFFE5484D);

final _baseColor = const Color.fromARGB(255, 12, 86, 147);
final _bannerGradient = LinearGradient(
  colors: [_baseColor, _baseColor.withOpacity(0.72)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _softShadow = [
  BoxShadow(
    color: const Color(0xFF1F2430).withOpacity(0.08),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
];

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty || email.isEmpty) {
      _showSnack("Please enter Username and Email", isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.verifyopt(username, email, '');

      if (!mounted) return;

      if (res == true) {
        _showSnack("OTP successfully sent to your email.");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              email: email,
              username: username,
            ),
          ),
        );
      } else {
        _showSnack("OTP failed, please try again.", isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack("Connection error. Please try again.", isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _kRed : _kGreen,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: _kMuted.withOpacity(0.6)),
      floatingLabelStyle:
          TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 20),
        ),
      ),
      filled: true,
      fillColor: _kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(_kLine),
      enabledBorder: border(_kLine),
      focusedBorder: border(Colors.blue, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              // ---------- Header ----------
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 88),
                decoration: BoxDecoration(
                  gradient: _bannerGradient,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Forgot Password',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "We'll email you a one-time code to reset it.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withOpacity(0.82),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- Form card (overlaps header) ----------
              Transform.translate(
                offset: const Offset(0, -56),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reset your password',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your username and email to receive an OTP.',
                        style: TextStyle(fontSize: 14, color: _kMuted),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                        style: const TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _fieldDecoration(
                          label: 'Username',
                          hint: 'Enter your username',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _isLoading ? null : _resetPassword(),
                        style: const TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _fieldDecoration(
                          label: 'Email Address',
                          hint: 'Enter your registered email',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SendButton(isLoading: _isLoading, onTap: _resetPassword),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text(
                            'Back to Login',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Transform.translate(
                offset: const Offset(0, -32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 16, color: _kMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Secure password recovery',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _kMuted.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SendButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isLoading ? 0.75 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: _bannerGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _baseColor.withOpacity(0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isLoading ? null : onTap,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_read_outlined,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Send OTP',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}