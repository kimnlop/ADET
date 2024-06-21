// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, library_private_types_in_public_api, prefer_final_fields, use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:Crowdcuts/feed_item.dart';

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
  bool _isPosting = false;
  bool _isPostingInProgress = false;
  bool _isLoading = true;
  String _photoName = '';

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

  Future<void> _refreshFeed() async {
    setState(() {
      _feedItems.clear();
    });
    _subscribeToFeed();
  }

  void _subscribeToFeed() {
    setState(() {
      _isLoading = true;
    });

    _feedSubscription = _firestore
        .collection('feedItems')
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs.reversed) {
        var userDoc =
            await _firestore.collection('users').doc(doc['userId']).get();
        String userName = userDoc['userName'];

        bool alreadyExists = _feedItems.any((item) => item.id == doc.id);

        if (!alreadyExists) {
          setState(() {
            _feedItems.insert(0, FeedItem.fromSnapshot(doc, userName));
          });
        }
      }

      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : Scaffold(
            body: RefreshIndicator(
              onRefresh: _refreshFeed,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _feedItems.length,
                itemBuilder: (context, index) {
                  var feedItem = _feedItems[index];
                  return _buildFeedItem(feedItem);
                },
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _isPosting ? null : _showPostDialog,
              label: Text('Create Post',
                  style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
              icon: Icon(Icons.add,
                  size: 24, color: Color.fromARGB(255, 0, 255, 17)),
              backgroundColor: const Color(0xFF50727B),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 28,
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      icon: Icon(
                        feedItem.reactions[
                                    FirebaseAuth.instance.currentUser?.uid] ==
                                'like'
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: feedItem.reactions[
                                    FirebaseAuth.instance.currentUser?.uid] ==
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
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      icon: Icon(
                        feedItem.reactions[
                                    FirebaseAuth.instance.currentUser?.uid] ==
                                'dope'
                            ? Icons.whatshot
                            : Icons.whatshot_outlined,
                        color: feedItem.reactions[
                                    FirebaseAuth.instance.currentUser?.uid] ==
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
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      icon: Icon(
                        feedItem.reactions[
                                    FirebaseAuth.instance.currentUser?.uid] ==
                                'scissor'
                            ? Icons.cut
                            : Icons.cut_outlined,
                        color: feedItem.reactions[
                                    FirebaseAuth.instance.currentUser?.uid] ==
                                'scissor'
                            ? Colors.blue
                            : null,
                      ),
                      onPressed: () =>
                          _toggleReaction(feedItem, 'scissor', setState),
                    ),
                    Text('${feedItem.scissorCount}'),
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

  void _toggleReaction(
      FeedItem feedItem, String reactionType, StateSetter setState) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final userId = currentUser.uid;

    FirebaseFirestore.instance.runTransaction((transaction) async {
      final feedItemRef =
          FirebaseFirestore.instance.collection('feedItems').doc(feedItem.id);
      final feedItemSnapshot = await transaction.get(feedItemRef);

      if (!feedItemSnapshot.exists) {
        return;
      }

      final currentReactions =
          Map<String, String>.from(feedItemSnapshot['reactions'] ?? {});

      if (currentReactions[userId] == reactionType) {
        // If the user has already reacted with this type, remove the reaction
        currentReactions.remove(userId);
      } else {
        // Otherwise, add or update the reaction
        currentReactions[userId] = reactionType;
      }

      transaction.update(feedItemRef, {'reactions': currentReactions});
    }).then((_) {
      // Update the local state to reflect the change immediately
      setState(() {
        if (feedItem.reactions[userId] == reactionType) {
          feedItem.reactions.remove(userId);
        } else {
          feedItem.reactions[userId] = reactionType;
        }

        feedItem.likesCount = feedItem.reactions.values
            .where((reaction) => reaction == 'like')
            .length;
        feedItem.dopeCount = feedItem.reactions.values
            .where((reaction) => reaction == 'dope')
            .length;
        feedItem.scissorCount = feedItem.reactions.values
            .where((reaction) => reaction == 'scissor')
            .length;
      });
    }).catchError((error) {
      print('Failed to update reaction: $error');
    });
  }

  void _showPostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title:
                  Text('New Post', style: TextStyle(color: Colors.deepPurple)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 20, // Limit title to 20 characters
                      decoration: InputDecoration(
                        hintText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        TextField(
                          controller: _descriptionController,
                          maxLength: 200,
                          minLines: 3,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          right: 8,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery, setState),
                                icon: Icon(Icons.photo_library),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _pickImage(ImageSource.camera, setState),
                                icon: Icon(Icons.camera_alt),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _photoController.text.isNotEmpty
                        ? Text(
                            _photoName,
                            style: TextStyle(color: Colors.green),
                          )
                        : SizedBox(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(255, 142, 33, 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      _isPosting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isPosting ? null : () => _post(setState),
                  child: _isPosting
                      ? CircularProgressIndicator()
                      : const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _pickImage(ImageSource source, StateSetter setState) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _photoController.text = pickedFile.path;
        _photoName = pickedFile.name;
      });
    }
  }

  void _post(StateSetter setState) async {
    if (_isPostingInProgress) {
      return;
    }

    setState(() {
      _isPostingInProgress = true;
      _isPosting = true;
    });

    var user = _auth.currentUser;
    if (user != null) {
      if (_titleController.text.trim().isEmpty) {
        _enablePosting(setState);
        _clearPostingInProgress();
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
        return;
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
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
    _enablePosting(setState);
    // Clear the flag
    _clearPostingInProgress();
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
    return filePath;
  }

  Future<String> _resolveIOSFilePath(String uriString) async {
    final uri = Uri.parse(uriString);
    final filePath = uri.path;
    return filePath;
  }

  void _clearControllers() {
    _titleController.clear();
    _descriptionController.clear();
    _photoController.clear();
    _photoName = '';
  }

  void _enablePosting(StateSetter setState) {
    setState(() {
      _isPosting = false;
    });
  }

  void _clearPostingInProgress() {
    _isPostingInProgress = false;
  }
}
