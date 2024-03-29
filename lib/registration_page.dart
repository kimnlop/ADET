// ignore_for_file: prefer_const_constructors, library_private_types_in_public_api, use_key_in_widget_constructors, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'success_page.dart';

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String _emailError = '';
  String _nameError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';

  bool get _isFormValid {
    return _emailError.isEmpty &&
        _nameError.isEmpty &&
        _passwordError.isEmpty &&
        _confirmPasswordError.isEmpty &&
        emailController.text.isNotEmpty &&
        userNameController.text.isNotEmpty &&
        passwordController.text.isNotEmpty &&
        confirmPasswordController.text.isNotEmpty &&
        passwordController.text == confirmPasswordController.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
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
                    children: <Widget>[
                      SizedBox(height: 400),
                      _buildTextField(
                        emailController,
                        'Email',
                        TextInputType.emailAddress,
                        _emailError,
                        RegExp(r'^[\w.-]+@[a-zA-Z]+\.[a-zA-Z]+$'),
                      ),
                      SizedBox(height: 20),
                      _buildTextField(
                        userNameController,
                        'Username',
                        TextInputType.text,
                        _nameError,
                        RegExp(r'^[a-zA-Z0-9 ]+$'),
                      ),
                      SizedBox(height: 20),
                      _buildTextField(
                        passwordController,
                        'Password',
                        TextInputType.visiblePassword,
                        _passwordError,
                        null,
                        isPassword: true,
                        isPasswordVisible: _passwordVisible,
                        togglePasswordVisibility: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                      ),
                      SizedBox(height: 20),
                      _buildTextField(
                        confirmPasswordController,
                        'Confirm Password',
                        TextInputType.visiblePassword,
                        _confirmPasswordError,
                        null,
                        isPassword: true,
                        isPasswordVisible: _confirmPasswordVisible,
                        togglePasswordVisibility: () => setState(() =>
                            _confirmPasswordVisible = !_confirmPasswordVisible),
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed:
                            (!_isFormValid || _isLoading) ? null : _register,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9.0),
                          child: _isLoading
                              ? CircularProgressIndicator()
                              : Text(
                                  'Register',
                                  style: TextStyle(fontSize: 15),
                                ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Back to Login",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    TextInputType keyboardType,
    String errorText,
    RegExp? regExp, {
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? togglePasswordVisibility,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword && !isPasswordVisible,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(10.0),
        ),
        errorText: errorText.isNotEmpty ? errorText : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(isPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: togglePasswordVisibility,
              )
            : null,
      ),
      onChanged: (value) => _validateField(label, value),
    );
  }

  void _validateField(String label, String value) {
    setState(() {
      if (label == 'Email' &&
          !RegExp(r'^[\w.-]+@[a-zA-Z]+\.[a-zA-Z]+$').hasMatch(value)) {
        _emailError = 'Invalid email format';
      } else if (label == 'Email') {
        _emailError = '';
      }
      if (label == 'Name' && !RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(value)) {
        _nameError = 'Invalid name format';
      } else if (label == 'Name') {
        _nameError = '';
      }
      if (label == 'Password') {
        bool passwordValid =
            RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$').hasMatch(value);
        _passwordError = passwordValid
            ? ''
            : 'Password must be at least 8 characters long and include a \nnumber';
      }
      if (label == 'Confirm Password' || label == 'Password') {
        _checkPasswordsMatch();
      }
    });
  }

  void _checkPasswordsMatch() {
    if (passwordController.text != confirmPasswordController.text) {
      _confirmPasswordError = 'Passwords do not match';
    } else {
      _confirmPasswordError = '';
    }
  }

  void _register() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final username = userNameController.text.trim().toLowerCase();
      final isTaken = await DatabaseService().isUsernameTaken(username);
      if (isTaken) {
        throw 'Username already taken';
      }

      final userCredential = await AuthService().signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      await DatabaseService().addUser(userCredential.user!.uid, {
        'email': emailController.text.trim(),
        'userName': username,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SuccessPage()),
      );
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
