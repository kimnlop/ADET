// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:Crowdcuts/feed_item.dart';

class MyAccountTab extends StatelessWidget {
  final Map<String, ImageProvider> _imageCache = {};

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
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
            return const Center(child: Text('Error loading feed items'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedItems = snapshot.data!.docs;

          if (feedItems.isEmpty) {
            return const Center(child: Text('No feed items found'));
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
                      trailing: const Icon(Icons.error, color: Colors.red),
                    );
                  }

                  if (!userNameSnapshot.hasData) {
                    return ListTile(
                      title: Text(feedItemData['title'] ?? 'No Title'),
                      subtitle:
                          Text(feedItemData['description'] ?? 'No Content'),
                      trailing: const CircularProgressIndicator(),
                    );
                  }

                  var feedItem = FeedItem.fromSnapshot(
                    feedItems[index],
                    userNameSnapshot.data!,
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
                              style: const TextStyle(
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
                                  const SnackBar(
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
                              _deleteFeedItem(feedItem.id, context);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              if (!isEditing)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                              if (isEditing)
                                const PopupMenuItem(
                                  value: 'save',
                                  child: Text('Save'),
                                ),
                              const PopupMenuItem(
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
                        maxLength: 200,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'by ${feedItem.userName}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feedItem.description,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 28,
                                padding: const EdgeInsets.only(
                                    left: 8.0, right: 8.0),
                                icon: Icon(
                                  feedItem.reactions[FirebaseAuth
                                              .instance.currentUser?.uid] ==
                                          'like'
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: feedItem.reactions[FirebaseAuth
                                              .instance.currentUser?.uid] ==
                                          'like'
                                      ? Colors.red
                                      : null,
                                ),
                                onPressed: () =>
                                    _toggleReaction(feedItem, 'like', setState),
                              ),
                              Text('${feedItem.likesCount}'),
                              IconButton(
                                iconSize: 28,
                                padding: const EdgeInsets.only(
                                    left: 8.0, right: 8.0),
                                icon: Icon(
                                  feedItem.reactions[FirebaseAuth
                                              .instance.currentUser?.uid] ==
                                          'dope'
                                      ? Icons.whatshot
                                      : Icons.whatshot_outlined,
                                  color: feedItem.reactions[FirebaseAuth
                                              .instance.currentUser?.uid] ==
                                          'dope'
                                      ? Colors.orange
                                      : null,
                                ),
                                onPressed: () =>
                                    _toggleReaction(feedItem, 'dope', setState),
                              ),
                              Text('${feedItem.dopeCount}'),
                              IconButton(
                                iconSize: 28,
                                padding: const EdgeInsets.only(
                                    left: 8.0, right: 8.0),
                                icon: Icon(
                                  feedItem.reactions[FirebaseAuth
                                              .instance.currentUser?.uid] ==
                                          'scissor'
                                      ? Icons.cut
                                      : Icons.cut_outlined,
                                  color: feedItem.reactions[FirebaseAuth
                                              .instance.currentUser?.uid] ==
                                          'scissor'
                                      ? Colors.blue
                                      : null,
                                ),
                                onPressed: () => _toggleReaction(
                                    feedItem, 'scissor', setState),
                              ),
                              Text('${feedItem.scissorCount}'),
                            ],
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
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Icon(Icons.error));
          } else {
            _imageCache[photoUrl] = snapshot.data!;
            return Image(image: snapshot.data!);
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
    }).then((_) {
      print('Feed item updated successfully');
    }).catchError((error) {
      print('Failed to update feed item: $error');
    });
  }

  void _deleteFeedItem(String feedItemId, BuildContext context) {
    FirebaseFirestore.instance
        .collection('feedItems')
        .doc(feedItemId)
        .delete()
        .then((_) {
      print('Feed item deleted successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feed item deleted successfully'),
          backgroundColor: Colors.red,
        ),
      );
    }).catchError((error) {
      print('Failed to delete feed item: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete feed item'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }
}
