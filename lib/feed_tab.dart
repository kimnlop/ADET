import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Color.fromRGBO(254, 173, 86, 1),
        ),
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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();

  TextEditingController _titleController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _photoController = TextEditingController();

  // Map to store loaded images
  final Map<String, ImageProvider> _imageCache = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
            controller: _scrollController,
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
                        photoUrl: feedItem['photoUrl'],
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
      margin: EdgeInsets.symmetric(vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 0,
            blurRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (feedItem.photoUrl != null)
            _buildCachedImage(feedItem.photoUrl!), // Load image from cache
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

  Widget _buildCachedImage(String photoUrl) {
    // Check if image is already loaded
    if (_imageCache.containsKey(photoUrl)) {
      return Image(image: _imageCache[photoUrl]!);
    } else {
      // If not, load image and store it in cache
      return FutureBuilder(
        future: _loadImage(photoUrl),
        builder: (context, AsyncSnapshot<ImageProvider> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading image'));
          } else {
            // Store image in cache
            _imageCache[photoUrl] = snapshot.data!;
            return Image(image: snapshot.data!);
          }
        },
      );
    }
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
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final pickedFile = await ImagePicker()
                            .pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setState(() {
                            _photoController.text = pickedFile.path!;
                          });
                        }
                      },
                      icon: Icon(Icons.photo_library),
                      label: Text('Choose Photo'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final pickedFile = await ImagePicker()
                            .pickImage(source: ImageSource.camera);
                        if (pickedFile != null) {
                          setState(() {
                            _photoController.text = pickedFile.path!;
                          });
                        }
                      },
                      icon: Icon(Icons.camera_alt),
                      label: Text('Take Photo'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              TextField(
                controller: _photoController,
                enabled: false,
                decoration: InputDecoration(
                  hintText: 'Photo',
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
                  String? photoUrl = await _uploadPhoto(_photoController.text);
                  await _firestore.collection('feedItems').add({
                    'title': _titleController.text,
                    'description': _descriptionController.text,
                    'upvotes': 0,
                    'upvoters': [],
                    'userId': user.uid,
                    'photoUrl': photoUrl,
                  });
                  _titleController.clear();
                  _descriptionController.clear();
                  _photoController.clear();
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

  Future<String?> _uploadPhoto(String photoUrl) async {
    if (photoUrl.isNotEmpty) {
      try {
        Uint8List imageData;
        if (kIsWeb) {
          http.Response response = await http.get(Uri.parse(photoUrl));
          imageData = response.bodyBytes;
        } else {
          String imagePath = '';
          if (Platform.isAndroid) {
            imagePath = await _resolveAndroidContentUri(photoUrl);
          } else if (Platform.isIOS) {
            imagePath = await _resolveIOSFilePath(photoUrl);
          }
          imageData = await File(imagePath).readAsBytes();
        }
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        TaskSnapshot snapshot =
            await _storage.ref().child('photos/$fileName').putData(imageData);
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        print('Error uploading photo: $e');
        return null;
      }
    }
    return null;
  }

  Future<String> _resolveAndroidContentUri(String uriString) async {
    final uri = Uri.parse(uriString);
    final filePath = uri.path;
    return filePath!;
  }

  Future<String> _resolveIOSFilePath(String uriString) async {
    final uri = Uri.parse(uriString);
    final filePath = uri.path;
    return filePath!;
  }
}

class FeedItem {
  final String id;
  final String title;
  final String description;
  int upvotes;
  final List<String> upvoters;
  final String userName;
  final String? photoUrl;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    this.upvotes = 0,
    required this.upvoters,
    required this.userName,
    this.photoUrl,
  });
}
