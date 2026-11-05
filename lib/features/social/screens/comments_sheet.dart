import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../models/comment_model.dart';
import '../services/social_service.dart';
import '../utils/relative_time.dart';
import '../models/post_model.dart';

/// Modal bottom sheet listing the comments of one post, with the composer
/// input to add a new one in real time (`GET/POST /api/posts/{id}/comments`).
class CommentsSheet extends StatefulWidget {
  final String postId;
  /// Called after a comment is successfully added so the caller can update
  /// its local counters or lists.
  final void Function(CommentModel comment)? onCommented;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.onCommented,
    this.currentUserId,
    this.onCommentDeleted,
  });

  /// Id of the authenticated user; enables the delete affordance on their comments.
  final int? currentUserId;

  /// Called after a comment is deleted so the caller can update its counters.
  final void Function(String commentId)? onCommentDeleted;

  /// Convenience wrapper so the caller shows the sheet with the right theme.
  static Future<void> show(
    BuildContext context, {
    required String postId,
    void Function(CommentModel)? onCommented,
    int? currentUserId,
    void Function(String commentId)? onCommentDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CommentsSheet(
          postId: postId,
          onCommented: onCommented,
          currentUserId: currentUserId,
          onCommentDeleted: onCommentDeleted,
        ),
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _socialService = SocialService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  List<CommentModel> _comments = const [];
  bool _loading = false;
  bool _failed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final comments = await _socialService.comments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _loading = false;
        });
        if (comments.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                  _scrollController.position.maxScrollExtent);
            }
          });
        }
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final created = await _socialService.addComment(widget.postId, content);
      _inputController.clear();
      if (mounted) {
        setState(() {
          _comments = [..._comments, created];
          _sending = false;
        });
        widget.onCommented?.call(created);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo enviar el comentario.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.subtext.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Comentarios',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
                : _failed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined,
                              color: AppColors.subtext),
                          const SizedBox(height: 8),
                          const Text('No se pudieron cargar los comentarios.'),
                          TextButton(onPressed: _load, child: const Text('Reintentar')),
                        ],
                      )
                    : _comments.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Sé el primero en comentar.',
                              style:
                                  TextStyle(color: AppColors.subtext, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: _comments.length,
                            itemBuilder: (_, i) => _item(_comments[i]),
                          ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _item(CommentModel c) {
    final avatar = absoluteUrl(c.userAvatarUrl);
    final isOwn = widget.currentUserId != null && c.userId == widget.currentUserId;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: avatar == null
          ? CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.blue,
              child: Text(
                c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              ),
            )
          : ClipOval(
              child: Image.network(avatar,
                  width: 32, height: 32, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.blue,
                        child: Text(c.userName.isNotEmpty
                            ? c.userName[0].toUpperCase()
                            : 'U',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12)),
                      )),
            ),
      title: Row(
        children: [
          Expanded(
            child: Text(c.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Text(
            RelativeTime.format(c.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.subtext),
          ),
        ],
      ),
      subtitle: Text(c.content, style: const TextStyle(fontSize: 13)),
      trailing: isOwn
          ? IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.subtext),
              tooltip: 'Eliminar comentario',
              onPressed: () => _confirmDelete(c),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(CommentModel c) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar comentario'),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await _socialService.deleteComment(widget.postId, c.id);
      if (mounted) {
        setState(() => _comments = _comments.where((x) => x.id != c.id).toList());
        widget.onCommentDeleted?.call(c.id);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo eliminar el comentario.')));
      }
    }
  }

  Widget _composer() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom == 0 ? 12 : 0,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                maxLength: 400,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                enabled: !_sending,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Escribe un comentario…',
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
