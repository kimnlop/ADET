// manage_users_page.dart

// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_feed_page.dart';

class ManageUsersPage extends StatefulWidget {
  @override
  _ManageUsersPageState createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserItem> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await _firestore.collection('users').get();
    List<UserItem> users = snapshot.docs.map((doc) {
      return UserItem.fromSnapshot(doc);
    }).toList();

    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _disableAccount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isDisabled': true,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Account has been disabled successfully')),
    );
    _fetchUsers(); // Refresh the user list after disabling an account
  }

  void _viewAccount(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFeedPage(userId: userId, userName: userName),
      ),
    );
  }

  void _confirmDisableAccount(String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Disable Account'),
          content: Text('Are you sure you want to disable this account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _disableAccount(userId);
              },
              child: Text('Disable'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                var userItem = _users[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userItem.userName,
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          userItem.email,
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _viewAccount(userItem.id, userItem.userName),
                              icon: Icon(Icons.remove_red_eye),
                              label: Text('View Account'),
                            ),
                            SizedBox(width: 8.0),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _confirmDisableAccount(userItem.id),
                              icon: Icon(Icons.block, color: Colors.white),
                              label: Text('Disable Account'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class UserItem {
  final String id;
  final String userName;
  final String email;

  UserItem({
    required this.id,
    required this.userName,
    required this.email,
  });

  factory UserItem.fromSnapshot(DocumentSnapshot snapshot) {
    return UserItem(
      id: snapshot.id,
      userName: snapshot['userName'],
      email: snapshot['email'],
    );
  }
}
