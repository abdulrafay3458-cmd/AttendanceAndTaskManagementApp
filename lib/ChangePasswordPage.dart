import 'package:attendance_app/login.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/profile.dart';
import 'package:flutter/material.dart';

const _kBg = Color(0xFFF5F6FA);
const _kInk = Color(0xFF1F2430);
const _kMuted = Color(0xFF7A8194);
const _kLine = Color(0xFFE6E8F0);
const _kGreen = Color(0xFF22A06B);
const _kRed = Color(0xFFE5484D);
const _kAmber = Color(0xFFE59A1F);

final _baseColor = const Color.fromARGB(255, 12, 86, 147);
final _bannerGradient = LinearGradient(
  colors: [_baseColor, _baseColor.withOpacity(0.72)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _softShadow = [
  BoxShadow(
    color: const Color(0xFF1F2430).withOpacity(0.06),
    blurRadius: 18,
    offset: const Offset(0, 6),
  ),
];

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool isLoading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    // Rebuild strength meter while typing.
    newPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (newPasswordController.text != confirmPasswordController.text) {
      _showError("New password and confirm password do not match.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.changePassword(
        oldPasswordController.text,
        newPasswordController.text,
      );

      if (response['success'] == true) {
        _showSuccess("Password updated successfully");
        await ApiService.clearCredentials();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      } else {
        _showError(response['message'] ?? "Failed to change password");
      }
    } catch (e) {
      _showError("Something went wrong. Please try again.");
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _showError(String message) => _snack(message, isError: true);
  void _showSuccess(String message) => _snack(message, isError: false);

  void _snack(String message, {required bool isError}) {
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

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    required bool visible,
    required VoidCallback onToggle,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w500),
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
      suffixIcon: IconButton(
        splashRadius: 20,
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _kMuted,
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: _kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(_kLine),
      enabledBorder: border(_kLine),
      focusedBorder: border(Colors.blue, 1.6),
      errorBorder: border(_kRed),
      focusedErrorBorder: border(_kRed, 1.6),
    );
  }

  // ---------------------------------------------------------- strength
  List<bool> get _rules {
    final p = newPasswordController.text;
    return [
      p.length >= 6,
      RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p),
      RegExp(r'\d').hasMatch(p),
      RegExp(r'[^A-Za-z0-9]').hasMatch(p),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          "Change Password",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            }
          },
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kLine),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBanner(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _softShadow,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: !_showOld,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _newFocus.requestFocus(),
                        style: const TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration(
                          "Old Password",
                          Icons.lock_outline_rounded,
                          visible: _showOld,
                          onToggle: () => setState(() => _showOld = !_showOld),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Old password is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        focusNode: _newFocus,
                        obscureText: !_showNew,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                        style: const TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration(
                          "New Password",
                          Icons.lock_rounded,
                          visible: _showNew,
                          onToggle: () => setState(() => _showNew = !_showNew),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "New password is required";
                          }

                          if (value.length < 6) {
                            return "Password must be at least 6 characters";
                          }

                          if (value == oldPasswordController.text) {
                            return "New password must differ from old password";
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _StrengthMeter(rules: _rules),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        focusNode: _confirmFocus,
                        obscureText: !_showConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => isLoading ? null : _submit(),
                        style: const TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration(
                          "Confirm Password",
                          Icons.verified_user_outlined,
                          visible: _showConfirm,
                          onToggle: () =>
                              setState(() => _showConfirm = !_showConfirm),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Confirm password is required";
                          }

                          if (value != newPasswordController.text) {
                            return "Passwords do not match";
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: _kMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'You will be signed out and asked to log in again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _kMuted.withOpacity(0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Update your password",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Choose a strong password you have not used before.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
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
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isLoading ? null : _submit,
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
                        Icon(Icons.lock_reset_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "Update Password",
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

// ====================================================================
// Password strength meter + requirement checklist
// ====================================================================

class _StrengthMeter extends StatelessWidget {
  /// [length>=6, upper+lower, digit, special]
  final List<bool> rules;

  const _StrengthMeter({required this.rules});

  @override
  Widget build(BuildContext context) {
    final score = rules.where((r) => r).length;
    final color = score <= 1
        ? _kRed
        : score == 2
            ? _kAmber
            : _kGreen;
    final label = score == 0
        ? 'Enter a password'
        : score <= 1
            ? 'Weak'
            : score == 2
                ? 'Fair'
                : score == 3
                    ? 'Good'
                    : 'Strong';

    const labels = [
      'At least 6 characters',
      'Upper & lower case letters',
      'A number',
      'A special character',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 6,
                        margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: i < score ? color : _kLine,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: score == 0 ? _kMuted : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    rules[i]
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: rules[i] ? _kGreen : _kMuted.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      color: rules[i] ? _kInk : _kMuted,
                      fontWeight: rules[i] ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}