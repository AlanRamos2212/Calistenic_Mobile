import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../../shared/widgets/post_card.dart';
import '../../../shared/widgets/section_label.dart';
import '../models/post_model.dart';
import '../services/social_service.dart';

/// Social feed connected to the real backend (`GET /api/posts`, likes and
/// publishing). Comments list UI is pending; the service already supports it.
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

  @override
  void initState() {
    super.initState();
    _loadFeed();
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
      final created = await _socialService.create(content);
      if (mounted) {
        setState(() {
          _posts = [created, ..._posts];
          _publishing = false;
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

  Future<void> _toggleLike(PostModel post) async {
    // Optimistic update; revert on failure.
    setState(() {
      _posts = _posts
          .map((p) => p.id == post.id
              ? PostModel(
                  id: p.id,
                  authorName: p.authorName,
                  authorUserId: p.authorUserId,
                  content: p.content,
                  achievement: p.achievement,
                  likes: p.likes + (p.likedByCurrentUser ? -1 : 1),
                  comments: p.comments,
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
                  ? PostModel(
                      id: p.id,
                      authorName: p.authorName,
                      authorUserId: p.authorUserId,
                      content: p.content,
                      achievement: p.achievement,
                      likes: liked
                          ? (p.likedByCurrentUser
                              ? p.likes
                              : p.likes + 1)
                          : (p.likedByCurrentUser ? p.likes - 1 : p.likes),
                      comments: p.comments,
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
                  ? PostModel(
                      id: p.id,
                      authorName: p.authorName,
                      authorUserId: p.authorUserId,
                      content: p.content,
                      achievement: p.achievement,
                      likes: post.likes,
                      comments: p.comments,
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.card),
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
          // Composer
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
                  content: post.content,
                  achievement: post.achievement,
                  likes: post.likes,
                  comments: post.comments,
                  liked: post.likedByCurrentUser,
                  onLike: () => _toggleLike(post),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
