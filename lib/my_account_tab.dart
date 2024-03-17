// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'login_page.dart';

class MyAccountTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min, // Use min to center the content vertically
        children: <Widget>[
          Text(
            'My Account Tab',
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(height: 20), // Add some space
          ElevatedButton(
            onPressed: () {
              // Logic to log out
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        LoginPage()), // Replace LoginPage() with your actual login page widget
                (Route<dynamic> route) => false,
              );
            },
            child: Text('Log Out'),
            // The 'primary' parameter isn't used here as ElevatedButton doesn't have it.
            // If you're customizing the button's colors, use style property.
          ),
        ],
      ),
    );
  }
}
