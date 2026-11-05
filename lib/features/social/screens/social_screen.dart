import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../../shared/widgets/post_card.dart';
import '../../../shared/widgets/section_label.dart';
import '../../auth/services/auth_service.dart';
import '../models/post_model.dart';
import '../services/social_service.dart';
import '../screens/comments_sheet.dart';

/// Social feed connected to the real backend (`GET /api/posts`, likes and
/// publishing). Comments open in a modal bottom sheet with like counters.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _socialService = SocialService();
  final _composerController = TextEditingController();
  List<PostModel> _posts = const [];
  bool _loading = false;
  bool _failed = false;
  bool _publishing = false;
  int? _currentUserId;
  File? _pickedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadFeed();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final profile = await AuthService().fetchProfile();
      final rawId = profile['id'];
      if (mounted) {
        setState(() => _currentUserId = rawId is num
            ? rawId.toInt()
            : int.tryParse('$rawId'));
      }
    } on ApiException {
      // The feed remains usable; the delete action stays hidden if the
      // authenticated profile cannot be loaded.
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final posts = await _socialService.feed();
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _publish() async {
    final content = _composerController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('Escribe algo antes de publicar.');
      return;
    }
    if (content.length > 500) {
      _showSnackBar('El post no puede exceder 500 caracteres.');
      return;
    }
    setState(() => _publishing = true);
    try {
      final created = await _socialService.create(content, imageFile: _pickedImage);
      if (mounted) {
        setState(() {
          _posts = [created, ..._posts];
          _publishing = false;
          _pickedImage = null;
        });
        _composerController.clear();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _publishing = false);
      _showSnackBar(e.message);
    } catch (e) {
      if (mounted) setState(() => _publishing = false);
      _showSnackBar('No se pudo publicar el post.');
    }
  }

  /// Lets the athlete attach a photo (camera or gallery); optional — a post
  /// can also be published with text only.
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked =
          await _imagePicker.pickImage(source: source, imageQuality: 70, maxWidth: 1920);
      if (picked != null && mounted) setState(() => _pickedImage = File(picked.path));
    } catch (e) {
      _showSnackBar('No se pudo seleccionar la imagen.');
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    // Optimistic update; revert on failure.
    setState(() {
      _posts = _posts
          .map((p) => p.id == post.id
              ? p.copyWith(
                  likes: p.likes + (p.likedByCurrentUser ? -1 : 1),
                  likedByCurrentUser: !p.likedByCurrentUser,
                )
              : p)
          .toList();
    });

    try {
      final liked = await _socialService.toggleLike(post.id);
      if (mounted) {
        setState(() {
          _posts = _posts
              .map((p) => p.id == post.id
                  ? p.copyWith(
                      likes: liked
                          ? (post.likedByCurrentUser ? post.likes : post.likes + 1)
                          : (post.likedByCurrentUser ? post.likes - 1 : post.likes),
                      likedByCurrentUser: liked,
                    )
                  : p)
              .toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _posts = _posts
              .map((p) => p.id == post.id
                  ? p.copyWith(
                      likes: post.likes,
                      likedByCurrentUser: post.likedByCurrentUser,
                    )
                  : p)
              .toList();
        });
        _showSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) _showSnackBar('No se pudo actualizar el like.');
    }
  }

  Future<void> _deletePost(PostModel post) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar publicación'),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await _socialService.delete(post.id);
      if (mounted) {
        setState(() => _posts = _posts.where((p) => p.id != post.id).toList());
        _showSnackBar('Publicación eliminada.');
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.card),
    );
  }

  /// Opens the comments modal; bumps the local comment counter of the post
  /// whenever a comment is added from the sheet.
  Future<void> _openComments(PostModel post) async {
    await CommentsSheet.show(
      context,
      postId: post.id,
      currentUserId: _currentUserId,
      onCommented: (comment) {
        if (mounted) {
          setState(() {
            _posts = _posts
                .map((p) => p.id == post.id
                    ? p.copyWith(comments: p.comments + 1)
                    : p)
                .toList();
          });
        }
      },
      onCommentDeleted: (commentId) {
        if (mounted) {
          setState(() {
            _posts = _posts
                .map((p) => p.id == post.id
                    ? p.copyWith(comments: p.comments > 0 ? p.comments - 1 : 0)
                    : p)
                .toList();
          });
        }
      },
    );
  }

  /// Miniature preview with a discard (x) control for the photo to attach.
  Widget _imagePreview() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _pickedImage!,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: AppColors.card,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _pickedImage = null),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FrameScaffold(
      title: 'Comunidad',
      onRefresh: () => _loadFeed(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('FEED SOCIAL'),
          const SizedBox(height: 8),
          const Text(
            'La comunidad entrena contigo',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 22),
          // Composer: text + optional photo preview
          if (_pickedImage != null) _imagePreview(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _composerController,
                  maxLength: 500,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'Comparte cómo va tu entrenamiento...',
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.blue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _publish(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.blue,
                  side: BorderSide(color: AppColors.cardBorder),
                ),
                tooltip: 'Adjuntar imagen',
                onPressed: _publishing ? null : _pickImage,
                icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              ),
              const SizedBox(width: 8),
              _publishing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.blue,
                      ),
                    )
                  : IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.blue,
                      ),
                      onPressed: _publish,
                      icon: const Icon(Icons.send, size: 20),
                    ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.blue),
              ),
            )
          else if (_failed)
            Column(
              children: [
                const Text(
                  'No se pudo cargar el feed de la comunidad.',
                  style: TextStyle(color: AppColors.subtext),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    side: const BorderSide(color: AppColors.blue),
                  ),
                  onPressed: _loadFeed,
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else if (_posts.isEmpty)
            const Text(
              'Todavía no hay posts. ¡Publica el primero!',
              style: TextStyle(color: AppColors.subtext),
            )
          else
            ..._posts.map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PostCard(
                  authorName: post.authorName,
                  authorAvatarUrl: post.authorAvatarUrl,
                  createdAt: post.createdAt,
                  imageUrl: post.imageUrl,
                  content: post.content,
                  achievement: post.achievement,
                  likes: post.likes,
                  comments: post.comments,
                  liked: post.likedByCurrentUser,
                  onLike: () => _toggleLike(post),
                  onComment: () => _openComments(post),
                  onShare: () => _showSnackBar('Compartir próximamente.'),
                  canDelete: _currentUserId != null &&
                      post.authorUserId == _currentUserId,
                  onDelete: () => _deletePost(post),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
