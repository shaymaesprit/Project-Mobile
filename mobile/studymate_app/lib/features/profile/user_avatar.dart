import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Avatar de l'étudiant : photo de profil, sinon ses initiales sur le dégradé
/// de la marque. [preview] (octets locaux) s'affiche pendant un envoi.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 20,
    this.preview,
    this.ring = false,
  });

  final String? photoUrl;
  final String? name;
  final double radius;
  final Uint8List? preview;

  /// Anneau dégradé autour de la photo (en-têtes).
  final bool ring;

  static String initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'[\s@._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final fallback = _Initials(name: name, size: size);
    final bytes = preview;
    final url = photoUrl;
    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
    } else if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      image = fallback;
    }
    final avatar = ClipOval(child: SizedBox.square(dimension: size, child: image));
    if (!ring) return avatar;
    final ringWidth = radius > 30 ? 3.5 : 2.0;
    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.brand,
      ),
      child: Container(
        padding: EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: avatar,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.size});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = UserAvatar.initials(name);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.brand),
      child: Center(
        child: text.isEmpty
            ? Icon(Icons.person_rounded, color: Colors.white, size: size * 0.55)
            : Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.38,
                ),
              ),
      ),
    );
  }
}
