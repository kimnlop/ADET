// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';
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
        primaryColor: const Color.fromRGBO(1, 67, 115, 1),
        buttonTheme: ButtonThemeData(
          buttonColor: const Color.fromRGBO(230, 72, 111, 1),
          textTheme: ButtonTextTheme.primary,
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color.fromRGBO(254, 173, 86, 1),
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

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _photoController = TextEditingController();

  late StreamSubscription<QuerySnapshot> _feedSubscription;
  final Map<String, ImageProvider> _imageCache = {};
  List<FeedItem> _feedItems = [];

  @override
  void initState() {
    super.initState();
    _subscribeToFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedSubscription.cancel();
    super.dispose();
  }

  void _subscribeToFeed() {
    _feedSubscription = _firestore
        .collection('feedItems')
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs.reversed) {
        // Reverse the order to prepend new items
        var userDoc =
            await _firestore.collection('users').doc(doc['userId']).get();
        String userName = userDoc['userName'];

        bool alreadyExists = _feedItems.any((item) => item.id == doc.id);

        if (!alreadyExists) {
          setState(() {
            _feedItems.insert(
                0, FeedItem.fromSnapshot(doc, userName)); // Prepend new items
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/crowdcutslogo2.png',
              height: 65, // Adjust the height as needed
            ),
          ],
        ),
        automaticallyImplyLeading: false, // Hide back button
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _feedItems.length,
        itemBuilder: (context, index) {
          var feedItem = _feedItems[index];
          return _buildFeedItem(feedItem);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPostDialog,
        label: Text('Create Post',
            style: TextStyle(color: const Color.fromRGBO(1, 67, 115, 1))),
        icon: Icon(Icons.add,
            size: 24, color: const Color.fromRGBO(254, 173, 86, 1)),
        backgroundColor: const Color.fromRGBO(230, 72, 111, 1),
      ),
    );
  }

  Widget _buildFeedItem(FeedItem feedItem) {
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
          if (feedItem.photoUrl != null) _buildCachedImage(feedItem.photoUrl!),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedItem.title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
          ),
        ],
      ),
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
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: Icon(Icons.photo_library),
                      label: Text('Choose Photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: Icon(Icons.camera_alt),
                      label: Text('Take Photo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
              onPressed: _post,
              child: Text('Post', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  void _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _photoController.text = pickedFile.path!;
      });
    }
  }

  void _post() async {
    var user = _auth.currentUser;
    if (user != null) {
      // Check if title is empty
      if (_titleController.text.trim().isEmpty) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text('Title cannot be empty.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return; // Exit the method if title is empty
      }

      String? photoUrl = await _uploadPhoto(_photoController.text);
      await _firestore.collection('feedItems').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'userId': user.uid,
        'photoUrl': photoUrl,
        'uploadDate': FieldValue.serverTimestamp(), // Set upload date
      });
      _clearControllers();
      Navigator.of(context).pop();

      // Scroll to the top of the feed
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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

  void _clearControllers() {
    _titleController.clear();
    _descriptionController.clear();
    _photoController.clear();
  }
}

class FeedItem {
  final String id;
  final String title;
  final String description;
  final String userId;
  final String userName;
  final String? photoUrl;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.userName,
    this.photoUrl,
  });

  factory FeedItem.fromSnapshot(DocumentSnapshot snapshot, String userName) {
    return FeedItem(
      id: snapshot.id,
      title: snapshot['title'],
      description: snapshot['description'],
      userId: snapshot['userId'],
      userName: userName,
      photoUrl: snapshot['photoUrl'],
    );
  }
}
