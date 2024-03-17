// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'success_page.dart'; // Import the success page

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  String _emailError = '';
  String _nameError = '';
  String _confirmPasswordError =
      ''; // Added error state for confirmation password

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
                      SizedBox(height: 400), // Lowered the input fields
                      _buildTextField(
                        emailController,
                        'Email',
                        TextInputType.emailAddress,
                        RegExp(r'^[\w.-]+@[a-zA-Z]+\.[a-zA-Z]+$'),
                        _emailError,
                      ),
                      SizedBox(height: 20), // Reduced spacing between fields
                      _buildTextField(
                        nameController,
                        'Name',
                        TextInputType.text,
                        RegExp(r'^[a-zA-Z0-9]+$'),
                        _nameError,
                      ),
                      SizedBox(height: 20), // Reduced spacing between fields
                      _buildTextField(
                        passwordController,
                        'Password',
                        TextInputType.visiblePassword,
                        null,
                        null, // No RegExp for passwords, but you might want to implement some checks
                        isPassword: true,
                      ),
                      SizedBox(height: 20), // Reduced spacing between fields
                      _buildTextField(
                        confirmPasswordController,
                        'Confirm Password',
                        TextInputType.visiblePassword,
                        null,
                        _confirmPasswordError, // Pass the confirm password error
                        isPassword: true,
                      ),
                      SizedBox(height: 30), // Increased spacing below fields
                      ElevatedButton(
                        onPressed:
                            _isLoading || _hasErrors() ? null : _register,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16.0), // Increased button size
                          child: _isLoading
                              ? CircularProgressIndicator()
                              : Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 15,
                                  ), // Increased button text size
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

  Widget _buildTextField(TextEditingController controller, String label,
      TextInputType keyboardType, RegExp? regExp, String? errorText,
      {bool isPassword = false}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.white.withOpacity(0.5),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(10.0),
          ),
          errorText: errorText?.isNotEmpty == true ? errorText : null,
        ),
        onChanged: (value) {
          if (regExp != null && !regExp.hasMatch(value)) {
            setState(() {
              if (label == 'Email') {
                _emailError = 'Invalid email format';
              } else if (label == 'Name') {
                _nameError = 'Invalid name format';
              }
            });
          } else {
            setState(() {
              if (label == 'Email') {
                _emailError = '';
              } else if (label == 'Name') {
                _nameError = '';
              }
            });
          }
          if (label == 'Confirm Password') {
            // Additional check for confirm password field
            if (passwordController.text != value) {
              setState(() => _confirmPasswordError = 'Passwords do not match');
            } else {
              setState(() => _confirmPasswordError = '');
            }
          }
        },
      ),
    );
  }

  bool _hasErrors() {
    return _emailError.isNotEmpty ||
        _nameError.isNotEmpty ||
        _confirmPasswordError.isNotEmpty;
  }

  void _register() async {
    if (passwordController.text != confirmPasswordController.text) {
      // If passwords don't match, set error and prevent further execution
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _confirmPasswordError =
          ''; // Reset error state upon attempting to register
    });

    try {
      final userCredential = await AuthService().signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      await DatabaseService().addUser(userCredential.user!.uid, {
        'email': emailController.text.trim(),
        'name': nameController.text.trim(),
      });

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Success"),
            content: Text("Your account has been successfully created."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SuccessPage()),
                  );
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Handle registration failure
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
