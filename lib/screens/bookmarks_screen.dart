import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bookmark.dart';
import '../services/app_state.dart';
import 'reading_screen.dart';

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  Future<void> _rename(BuildContext context, Bookmark bookmark) async {
    final controller = TextEditingController(text: bookmark.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename bookmark'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Bookmark name'),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<AppState>().renameBookmark(bookmark.id, name);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Bookmark bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete bookmark?'),
        content: Text("'${bookmark.name}' will be gone for good."),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().deleteBookmark(bookmark.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bookmarks = appState.bookmarks;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Bookmarks')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: bookmarks.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          final surah = appState.quran.surahByNumber(bookmark.surahNumber);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: Icon(
              bookmark.isDefault ? Icons.home_rounded : Icons.bookmark_outline_rounded,
              color: bookmark.isDefault ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(bookmark.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${surah.englishName} · ayah ${bookmark.ayahNumber} · updated ${_relativeTime(bookmark.updatedAt)}',
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
              onSelected: (action) {
                switch (action) {
                  case 'default':
                    context.read<AppState>().setDefaultBookmark(bookmark.id);
                  case 'rename':
                    _rename(context, bookmark);
                  case 'delete':
                    _confirmDelete(context, bookmark);
                }
              },
              itemBuilder: (context) => [
                if (!bookmark.isDefault)
                  const PopupMenuItem(value: 'default', child: Text('Show on home screen')),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                if (bookmarks.length > 1)
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: colorScheme.error))),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReadingScreen(
                  initialSurahNumber: bookmark.surahNumber,
                  initialAyahNumber: bookmark.ayahNumber,
                  updatesContinuePoint: bookmark.isDefault,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
