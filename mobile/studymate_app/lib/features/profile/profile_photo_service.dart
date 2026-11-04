import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/firebase_config.dart';

class ProfilePhotoService {
  ProfilePhotoService._();

  static const _maxPhotoBytes = 5 * 1024 * 1024;
  static final _picker = ImagePicker();

  static Future<String?> selectAndUpload(User user) async {
    final bucket = StudyMateFirebaseConfig.storageBucket;
    if (bucket == null) {
      throw StateError(
        'Configure STUDYMATE_FIREBASE_STORAGE_BUCKET avec le bucket '
        'Storage du projet Firebase.',
      );
    }

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      throw StateError('La photo doit faire 5 Mo maximum.');
    }

    final contentType = _contentType(image.name);
    final storageBucket = bucket.startsWith('gs://') ? bucket : 'gs://$bucket';
    final reference = FirebaseStorage.instanceFor(bucket: storageBucket)
        .ref()
        .child('users/${user.uid}/profile/avatar');
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=3600',
      customMetadata: {'ownerUid': user.uid},
    );

    await reference.putData(bytes, metadata);
    return reference.getDownloadURL();
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
