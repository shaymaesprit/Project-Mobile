import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/config/firebase_config.dart';

/// An image selected by the user, validated but not yet uploaded.
class PickedProfilePhoto {
  const PickedProfilePhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class ProfilePhotoService {
  ProfilePhotoService._();

  static const _maxPhotoBytes = 5 * 1024 * 1024;
  static final _picker = ImagePicker();

  /// Lets the user choose an image and validates its format and size.
  /// Returns `null` when the picker is dismissed.
  static Future<PickedProfilePhoto?> pick({
    ImageSource source = ImageSource.gallery,
  }) async {
    final image = await _picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;

    final contentType = _contentType(image.name);
    final bytes = await image.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      throw StateError('La photo doit faire 5 Mo maximum.');
    }
    return PickedProfilePhoto(bytes: bytes, contentType: contentType);
  }

  /// Uploads [photo] to Cloudinary and returns its download URL.
  static Future<String> upload(String uid, PickedProfilePhoto photo) async {
    if (!StudyMateFirebaseConfig.cloudinaryConfigured) {
      throw StateError('Cloudinary n\'est pas configuré.');
    }

    final cloudName = StudyMateFirebaseConfig.cloudinaryCloudName;
    final apiKey = StudyMateFirebaseConfig.cloudinaryApiKey;
    final apiSecret = StudyMateFirebaseConfig.cloudinaryApiSecret;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final publicId = 'users/$uid/profile/avatar';
    final folder = 'studymate';

    // Generate signature
    final toSign = 'folder=$folder&public_id=$publicId&timestamp=$timestamp$apiSecret';
    final signature = sha1.convert(utf8.encode(toSign)).toString();

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp
      ..fields['signature'] = signature
      ..fields['public_id'] = publicId
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        photo.bytes,
        filename: 'avatar.${photo.contentType.split('/').last}',
      ));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw StateError('Upload Cloudinary échoué (${response.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('URL non reçue de Cloudinary.');
    }
    return url;
  }

  static Future<String?> selectAndUpload(String uid) async {
    final photo = await pick();
    if (photo == null) return null;
    return upload(uid, photo);
  }

  static String _contentType(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw StateError('Choisis une image JPG, PNG ou WebP.'),
    };
  }
}
