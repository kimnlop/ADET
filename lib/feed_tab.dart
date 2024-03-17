// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color.fromRGBO(1, 67, 115, 1),
        buttonTheme: ButtonThemeData(
          buttonColor: Color.fromRGBO(230, 72, 111, 1),
          textTheme: ButtonTextTheme.primary,
        ),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: Color.fromRGBO(254, 173, 86, 1)),
      ),
      home: FeedTab(),
    );
  }
}

class FeedTab extends StatefulWidget {
  @override
  _FeedTabState createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController _titleController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: _firestore
            .collection('feedItems')
            .orderBy('upvotes', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var feedItem = snapshot.data!.docs[index];
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('users')
                    .doc(feedItem['userId'])
                    .get(),
                builder: (BuildContext context,
                    AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.done) {
                    if (userSnapshot.hasData && userSnapshot.data != null) {
                      String userName = userSnapshot.data!['name'];
                      return _buildFeedItem(FeedItem(
                        id: feedItem.id,
                        title: feedItem['title'],
                        description: feedItem['description'],
                        upvotes: feedItem['upvotes'],
                        upvoters: List<String>.from(feedItem['upvoters'] ?? []),
                        userName: _hideMiddleCharacters(userName),
                      ));
                    } else {
                      return SizedBox(); // Return empty widget if user data not available
                    }
                  } else {
                    return SizedBox(); // Return empty widget while data is loading
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPostDialog,
        label: Text('Create Post',
            style: TextStyle(color: Color.fromRGBO(1, 67, 115, 1))),
        icon: Icon(Icons.add, size: 24, color: Color.fromRGBO(254, 173, 86, 1)),
        backgroundColor: Color.fromRGBO(230, 72, 111, 1),
      ),
    );
  }

  Widget _buildFeedItem(FeedItem feedItem) {
    return Container(
      margin: EdgeInsets.symmetric(
          vertical: 2.0), // Tiny vertical space between feed items
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 0,
            blurRadius: 2,
            offset: Offset(0, 2), // Shadow effect
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              feedItem.userName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedItem.title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  feedItem.description,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.content_cut,
                        color:
                            feedItem.upvoters.contains(_auth.currentUser?.uid)
                                ? Color.fromRGBO(254, 173, 86, 1)
                                : Colors.grey,
                      ),
                      onPressed: () => _handleUpvote(feedItem),
                    ),
                    Text(
                      '${feedItem.upvotes}',
                      style: TextStyle(fontSize: 16),
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

  String _hideMiddleCharacters(String name) {
    int middle = name.length ~/ 2;
    return name.replaceRange(middle - 1, middle + 2, '***');
  }

  void _handleUpvote(FeedItem feedItem) {
    var user = _auth.currentUser;
    if (user != null && !feedItem.upvoters.contains(user.uid)) {
      _firestore.collection('feedItems').doc(feedItem.id).update({
        'upvotes': FieldValue.increment(1),
        'upvoters': FieldValue.arrayUnion([user.uid]),
      });
    }
  }

  void _showPostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('New Post', style: TextStyle(color: Colors.deepPurple)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () async {
                var user = _auth.currentUser;
                if (user != null) {
                  await _firestore.collection('feedItems').add({
                    'title': _titleController.text,
                    'description': _descriptionController.text,
                    'upvotes': 0,
                    'upvoters': [],
                    'userId': user.uid,
                  });
                  _titleController.clear();
                  _descriptionController.clear();
                  Navigator.of(context).pop();
                }
              },
              child: Text('Post', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }
}

class FeedItem {
  final String id;
  final String title;
  final String description;
  int upvotes;
  final List<String> upvoters;
  final String userName;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    this.upvotes = 0,
    required this.upvoters,
    required this.userName,
  });
}
