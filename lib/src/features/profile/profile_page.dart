import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/shared/widgets/live_char_counter_text_field.dart';
import 'package:students_reminder/src/widgets/user_banner_notifications.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _onLogout(BuildContext context) async {
    try {
      //Confirm first
      final safeToLogout = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Yes'),
            ),
          ],
        ),
      );

      // Check if widget is still mounted after dialog
      if (!mounted || safeToLogout != true) return;

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Logging out...'),
              ],
            ),
          ),
        );
      }

      await AuthService.instance.logout();

      // Pop loading dialog if still mounted
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Navigation will be handled automatically by SplashGate
    } catch (e) {
      // Pop loading dialog if it exists and widget is still mounted
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        displaySnackBar(context, 'Error logging out: $e');
      }
    }
  }

  //Update Profile
  Future<void> _updateProfile() async {
    setState(() => _busy = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return; // User logged out during operation

      await UserService.instance.updateMyProfile(
        user.uid,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: _phone.text.trim(),
        bio: _bio.text.trim(),
      );
      if (mounted) {
        displaySnackBar(context, 'Profile updated!');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  //Upload/Select image
  Future<void> _onPickPhoto() async {
    setState(() => _busy = true);
    try {
      // Request permissions
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) {
          displaySnackBar(
            context,
            'Photo permission is required to select images',
          );
        }
        setState(() => _busy = false);
        return;
      }

      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (file == null) {
        setState(() => _busy = false);
        return;
      }

      // Load image data for cropping
      final imageBytes = await file.readAsBytes();
      setState(() {
        _imageData = imageBytes;
        _busy = false;
      });

      // Show cropping dialog
      _showCropDialog();
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, 'Error picking image: $e');
      }
      setState(() => _busy = false);
    }
  }

  void _showCropDialog() {
    if (_imageData == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          height: 400,
          width: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Crop Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Crop(
                  image: _imageData!,
                  controller: _cropController,
                  onCropped: (croppedData) {
                    Navigator.of(context).pop();
                    _uploadCroppedImage(croppedData);
                  },
                  aspectRatio: 1.0, // Square aspect ratio
                  baseColor: Color(0xFFF7F9FC),
                  maskColor: Colors.black.withOpacity(0.5),
                  radius: 0,
                  interactive: true,
                  fixCropRect: false,
                  cornerDotBuilder: (size, edgeAlignment) => const DotControl(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() => _imageData = null);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => _cropController.crop(),
                    child: const Text('Crop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadCroppedImage(dynamic croppedData) async {
    setState(() => _busy = true);
    try {
      Uint8List imageBytes;
      if (croppedData is Uint8List) {
        imageBytes = croppedData;
      } else {
        // In crop_your_image 2.0.0, the correct property is 'croppedImage'
        try {
          final dynamic cropResult = croppedData;

          // Try the correct property name for crop_your_image v2.0.0
          try {
            imageBytes = cropResult.croppedImage as Uint8List;
          } catch (e1) {
            // Fallback: try other possible property names
            try {
              imageBytes = cropResult.bytes as Uint8List;
            } catch (e2) {
              try {
                imageBytes = cropResult.data as Uint8List;
              } catch (e3) {
                // Try direct casting as last resort
                try {
                  imageBytes = cropResult as Uint8List;
                } catch (castError) {
                  throw Exception(
                    'Could not extract image bytes from CropSuccess object. Tried: croppedImage, bytes, data, direct casting',
                  );
                }
              }
            }
          }
        } catch (extractionError) {
          rethrow;
        }
      }

      // Create a temporary file from the cropped data
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(imageBytes);

      final user = AuthService.instance.currentUser;
      if (user == null) return; // User logged out during operation

      await UserService.instance.uploadProfilePhoto(
        uid: user.uid,
        file: tempFile,
      );

      // Clean up the temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (mounted) {
        displaySnackBar(context, 'Profile photo updated!');
      }

      setState(() => _imageData = null);
    } catch (e) {
      displaySnackBar(context, 'Error uploading cropped image: $e');
      if (mounted) {
        displaySnackBar(context, 'Error updating photo: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Cover image upload functionality
  Future<void> _onPickCoverImage() async {
    setState(() => _coverBusy = true);
    try {
      // Request permissions
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) {
          displaySnackBar(
            context,
            'Photo permission is required to select images',
          );
        }
        setState(() => _coverBusy = false);
        return;
      }

      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 800,
      );

      if (file == null) {
        setState(() => _coverBusy = false);
        return;
      }

      // Upload cover image without cropping (landscape format)
      final user = AuthService.instance.currentUser;
      if (user == null) {
        setState(() => _coverBusy = false);
        return; // User logged out during operation
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('covers')
          .child('${user.uid}.jpg');

      final uploadTask = storageRef.putFile(File(file.path));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with cover URL
      await UserService.instance.updateCoverImage(user.uid, downloadUrl);

      if (mounted) {
        displaySnackBar(context, 'Cover image updated!');
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, 'Error updating cover image: $e');
      }
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  final _bio = TextEditingController();
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  String? _photoUrl;
  String? _coverUrl; // Add cover image URL
  bool _busy = false;
  bool _coverBusy = false; // Separate loading state for cover image

  // Cropping state variables
  Uint8List? _imageData;
  final _cropController = CropController();

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    if (user != null) {
      UserService.instance.getUser(user.uid).listen((doc) {
        final data = doc.data();
        if (data != null && mounted) {
          _firstName.text = (data['firstName'] ?? '') as String;
          _lastName.text = (data['lastName'] ?? '') as String;
          _bio.text = (data['bio'] ?? '') as String;
          _phone.text = (data['phone'] ?? '') as String;
          setState(() {
            _photoUrl = data['photoUrl'] as String?;
            _coverUrl = data['coverUrl'] as String?; // Listen for cover URL
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    // If user is null, redirect to login
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SuspensionCheck(
        restrictWriteAccess: true,
        child: CustomScrollView(
          slivers: [
            // Collapsible cover image with SliverAppBar
            SliverAppBar(
              backgroundColor: Color(0xFF2C3E50),
              foregroundColor: Colors.white,
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              actions: [
                IconButton(
                  onPressed: () => _onLogout(context),
                  icon: Icon(Icons.logout),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text('My Profile'),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover image or placeholder
                    _coverUrl != null
                        ? Image.network(
                            _coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildCoverPlaceholder();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildCoverPlaceholder(),
                    // Gradient overlay for better text readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF2C3E50).withOpacity(0.3),
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    // Change cover button for current user
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        onPressed: _coverBusy ? null : _onPickCoverImage,
                        child: _coverBusy
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.camera_alt, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Profile content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User notifications for flags/suspensions
                    const UserBannerNotifications(),
                    const SizedBox(height: 16),
                    // Profile image section
                    Center(
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _busy
                                  ? Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : _photoUrl != null
                                  ? Image.network(
                                      _photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _busy ? null : _onPickPhoto,
                        label: Text(
                          _busy ? 'Uploading...' : 'Change Profile Image',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // User info section
                    Text('Name: ${_firstName.text} ${_lastName.text}'),
                    const SizedBox(height: 8),
                    Text('Email: ${user.email}'),
                    const SizedBox(height: 24),
                    // Editable fields
                    TextField(
                      controller: _firstName,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _lastName,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone #',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LiveCharCounterTextField(
                      controller: _bio,
                      maxLength: 100,
                      labelText: 'Bio',
                      hintText: 'Tell us about yourself...',
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                    ),
                    const SizedBox(height: 24),
                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _updateProfile,
                        child: _busy
                            ? const CircularProgressIndicator()
                            : const Text('Save Profile'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await AuthService.instance.sendPasswordReset(
                            user.email!,
                          );
                          if (mounted) {
                            displaySnackBar(
                              context,
                              'Password reset email sent!',
                            );
                          }
                        },
                        child: const Text('Send Password Reset Email'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await AuthService.instance.logout();
                        },
                        child: const Text('Logout'),
                      ),
                    ),

                    const SizedBox(height: 24), // Extra bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.8),
            Theme.of(context).primaryColor.withOpacity(0.4),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape,
          size: 60,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }
}
