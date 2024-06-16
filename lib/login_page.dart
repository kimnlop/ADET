// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, sort_child_properties_last, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'registration_page.dart';
import 'success_page.dart'; // Import the SuccessPage widget

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false; // Track loading state
  bool _passwordVisible = false; // Track password visibility
  String _emailError = ''; // Track email error
  int _attempts = 0; // Track login attempts
  bool _isCooldown = false; // Track if user is in cooldown period
  Timer? _cooldownTimer; // Timer for cooldown period

  @override
  void dispose() {
    _cooldownTimer?.cancel(); // Cancel the timer if the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/crowdcutsbg.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 435),
                      _buildTextField(emailController, 'Email',
                          TextInputType.emailAddress, _emailError),
                      const SizedBox(height: 20),
                      _buildTextField(passwordController, 'Password',
                          TextInputType.visiblePassword, '',
                          isPassword: true,
                          isPasswordVisible: _passwordVisible,
                          togglePasswordVisibility: _togglePasswordVisibility),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading || _isCooldown ? null : _login,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 9.0),
                          child: Text('Login', style: TextStyle(fontSize: 15)),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              const Color(0xFF50727B), // Text color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(
                          height: 20), // Increased space between buttons
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RegistrationPage()));
                        },
                        child: const Text("Register",
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading ||
              _isCooldown) // Show loader overlay if loading or in cooldown
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Too many attempts. Please wait 30 seconds.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      TextInputType keyboardType, String errorText,
      {bool isPassword = false,
      bool isPasswordVisible = false,
      VoidCallback? togglePasswordVisibility}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword && !isPasswordVisible,
        style: const TextStyle(fontSize: 16.0),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.white.withOpacity(0.4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white),
              borderRadius: BorderRadius.circular(10.0)),
          errorText: errorText.isNotEmpty ? errorText : null,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(isPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: togglePasswordVisibility)
              : null,
        ),
      ),
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _passwordVisible = !_passwordVisible;
    });
  }

  void _login() async {
    if (emailController.text.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      return;
    }

    setState(() {
      _emailError = '';
      _isLoading = true; // Start loading
    });

    try {
      await AuthService()
          .signIn(emailController.text.trim(), passwordController.text.trim());
      // Reset attempts on successful login
      setState(() {
        _attempts = 0;
      });
      // Navigate to the home screen if successful, and prevent back navigation to login
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => SuccessPage()));
    } catch (e) {
      setState(() {
        _attempts++;
      });

      // Check if the error is due to a disabled account
      if (e.toString().contains('Account is disabled')) {
        _showErrorDialog(
            "Your account is disabled. Please contact support for assistance.");
      } else {
        if (_attempts >= 3) {
          _startCooldown();
        } else {
          // Handle error, e.g., show error message
          _showErrorDialog(
              "Failed to login. Please check your credentials and try again.");
        }
      }
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  void _startCooldown() {
    setState(() {
      _isCooldown = true;
      _isLoading = false;
    });
    _cooldownTimer = Timer(const Duration(seconds: 30), () {
      setState(() {
        _isCooldown = false;
        _attempts = 0; // Reset attempts after cooldown
      });
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title:
              const Text("Error", style: TextStyle(color: Color(0xFF50727B))),
          content: Text(message),
          actions: <Widget>[
            _buildAlertDialogButton(
              label: 'OK',
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss alert dialog
              },
              backgroundColor: const Color(0xFF50727B),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertDialogButton({
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return TextButton(
      child: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
    );
  }
}
