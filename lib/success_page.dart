import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'feed_tab.dart';
import 'haircut_recommender_tab.dart';
import 'my_account_tab.dart';
import 'admin_page.dart';
import 'manage_users_page.dart';
import 'auth_service.dart';
import 'login_page.dart'; // Import your login page

class SuccessPage extends StatefulWidget {
  @override
  _SuccessPageState createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    bool isAdmin = await _authService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
      if (_isAdmin) {
        _widgetOptions = <Widget>[
          AdminPage(),
          ManageUsersPage(),
        ];
      } else {
        _widgetOptions = <Widget>[
          FeedTab(),
          HaircutRecommenderTab(),
          MyAccountTab(),
        ];
      }
    });
  }

  List<Widget> _widgetOptions = <Widget>[]; // Initialize empty

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
    FirebaseAuth.instance.signOut().then((value) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hide back button
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0), // Adjust as needed
              child: Image.asset(
                'assets/crowdcutslogo2.png', // Replace with your logo image path
                height: 40, // Adjust height as needed
              ),
            ),
            Text(
              _isAdmin ? 'Admin Dashboard' : 'Crowdcuts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("Confirm Logout"),
                    content: Text("Are you sure you want to logout?"),
                    actions: <Widget>[
                      TextButton(
                        child: Text("Cancel"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text("Yes"),
                        onPressed: () {
                          _logout();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _widgetOptions.isNotEmpty
          ? IndexedStack(
              index: _selectedIndex,
              children: _widgetOptions,
            )
          : Center(
              child: CircularProgressIndicator(),
            ), // Show loader until tabs are set
      bottomNavigationBar: BottomNavigationBar(
        items: _isAdmin
            ? const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Manage Users',
                ),
              ]
            : const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Haircut Recommender',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle),
                  label: 'My Account',
                ),
              ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }
}
