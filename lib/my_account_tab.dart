import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class MyAccountTab extends StatelessWidget {
  final Map<String, ImageProvider> _imageCache = {};

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text('No user logged in'),
        ),
      );
    }

    final String userId = currentUser.uid;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedItems')
            .where('userId', isEqualTo: userId)
            .orderBy('uploadDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading feed items'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final feedItems = snapshot.data!.docs;

          if (feedItems.isEmpty) {
            return Center(child: Text('No feed items found'));
          }

          return ListView.builder(
            itemCount: feedItems.length,
            itemBuilder: (context, index) {
              var feedItemData =
                  feedItems[index].data() as Map<String, dynamic>;

              return FutureBuilder<String>(
                future: _fetchUserName(feedItemData['userId']),
                builder: (context, userNameSnapshot) {
                  if (userNameSnapshot.hasError) {
                    return ListTile(
                      title: Text(feedItemData['title'] ?? 'No Title'),
                      subtitle:
                          Text(feedItemData['description'] ?? 'No Content'),
                      trailing: Icon(Icons.error, color: Colors.red),
                    );
                  }

                  if (!userNameSnapshot.hasData) {
                    return ListTile(
                      title: Text(feedItemData['title'] ?? 'No Title'),
                      subtitle:
                          Text(feedItemData['description'] ?? 'No Content'),
                      trailing: CircularProgressIndicator(),
                    );
                  }

                  var feedItem = FeedItem(
                    id: feedItems[index].id,
                    title: feedItemData['title'] ?? 'Untitled',
                    description: feedItemData['description'] ?? '',
                    userId: feedItemData['userId'],
                    userName: userNameSnapshot.data!,
                    photoUrl: feedItemData['photoUrl'],
                  );

                  return _buildFeedItem(feedItem, context);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _fetchUserName(String userId) async {
    var userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc['userName'] ?? 'Unknown';
  }

  Widget _buildFeedItem(FeedItem feedItem, BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isEditing = feedItem.isEditing;
        TextEditingController titleController =
            TextEditingController(text: feedItem.title);
        TextEditingController descriptionController =
            TextEditingController(text: feedItem.description);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (feedItem.photoUrl != null)
                _buildCachedImage(feedItem.photoUrl!),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isEditing)
                          Expanded(
                            child: TextField(
                              controller: titleController,
                              maxLength: 20,
                              maxLines: 1,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                errorText: titleController.text.trim().isEmpty
                                    ? 'Title cannot be empty'
                                    : null,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Text(
                              feedItem.title,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              setState(() {
                                feedItem.isEditing = true;
                              });
                            } else if (value == 'save') {
                              if (titleController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Title cannot be empty or spaces only. Please provide a valid title.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } else {
                                _saveFeedItem(feedItem, titleController.text,
                                    descriptionController.text);
                                setState(() {
                                  feedItem.title = titleController.text;
                                  feedItem.description =
                                      descriptionController.text;
                                  feedItem.isEditing = false;
                                });
                              }
                            } else if (value == 'delete') {
                              _deleteFeedItem(feedItem.id);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              if (!isEditing)
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                              if (isEditing)
                                PopupMenuItem(
                                  value: 'save',
                                  child: Text('Save'),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                    if (isEditing)
                      TextField(
                        controller: descriptionController,
                        maxLines: null,
                        decoration: InputDecoration(
                          labelText: 'Description',
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'by ${feedItem.userName}',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feedItem.description,
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
      },
    );
  }

  Widget _buildCachedImage(String photoUrl) {
    if (_imageCache.containsKey(photoUrl)) {
      return Image(image: _imageCache[photoUrl]!);
    } else {
      return FutureBuilder(
        future: _loadImage(photoUrl),
        builder: (context, AsyncSnapshot<ImageProvider> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading image'));
          } else if (snapshot.hasData) {
            _imageCache[photoUrl] = snapshot.data!;
            return Image(image: snapshot.data!);
          } else {
            return Center(child: Text('No image available'));
          }
        },
      );
    }
  }

  Future<ImageProvider> _loadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return MemoryImage(response.bodyBytes);
      } else {
        throw Exception('Failed to load image');
      }
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }

  Future<void> _saveFeedItem(
      FeedItem feedItem, String newTitle, String newDescription) async {
    await FirebaseFirestore.instance
        .collection('feedItems')
        .doc(feedItem.id)
        .update({
      'title': newTitle,
      'description': newDescription,
    });
  }

  void _deleteFeedItem(String feedItemId) async {
    await FirebaseFirestore.instance
        .collection('feedItems')
        .doc(feedItemId)
        .delete();
  }
}

class FeedItem {
  final String id;
  String title;
  String description;
  final String userId;
  final String userName;
  final String? photoUrl;
  bool isEditing = false;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.userName,
    this.photoUrl,
  });
}
