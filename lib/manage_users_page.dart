// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

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
  List<UserItem> _filteredUsers = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _usersPerPage = 10;
  TextEditingController _searchController = TextEditingController();

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

    users.sort((a, b) => a.userName.compareTo(b.userName));

    if (mounted) {
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    List<UserItem> filteredList = _users.where((user) {
      return user.userName.toLowerCase().contains(query.toLowerCase()) ||
          user.email.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredUsers = filteredList;
      _currentPage = 1;
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

  void _nextPage() {
    setState(() {
      if (_currentPage * _usersPerPage < _filteredUsers.length) {
        _currentPage++;
      }
    });
  }

  void _previousPage() {
    setState(() {
      if (_currentPage > 1) {
        _currentPage--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int startIndex = (_currentPage - 1) * _usersPerPage;
    int endIndex = startIndex + _usersPerPage;
    List<UserItem> paginatedUsers = _filteredUsers.sublist(
      startIndex,
      endIndex > _filteredUsers.length ? _filteredUsers.length : endIndex,
    );
    int totalPages = (_filteredUsers.length / _usersPerPage).ceil();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterUsers,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 48), // Space for View Account button
                SizedBox(width: 48), // Space for Disable Account button
              ],
            ),
          ),
          Divider(),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(8.0),
                          itemCount: paginatedUsers.length,
                          itemBuilder: (context, index) {
                            var userItem = paginatedUsers[index];
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 8.0),
                              elevation: 4.0,
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        userItem.userName,
                                        style: TextStyle(
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        userItem.email,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.remove_red_eye),
                                      onPressed: () => _viewAccount(
                                          userItem.id, userItem.userName),
                                    ),
                                    IconButton(
                                      icon:
                                          Icon(Icons.block, color: Colors.red),
                                      onPressed: () =>
                                          _confirmDisableAccount(userItem.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_left),
                            onPressed: _previousPage,
                          ),
                          Text('$_currentPage / $totalPages'),
                          IconButton(
                            icon: Icon(Icons.arrow_right),
                            onPressed: _nextPage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ],
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
