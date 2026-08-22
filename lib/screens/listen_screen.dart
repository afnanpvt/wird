import 'package:flutter/material.dart';

import '../widgets/surah_list_view.dart';

/// A dedicated home for "just play something" - tapping any row starts that
/// Surah's recitation directly (via [SurahListView]'s `tapToListen: true`),
/// rather than opening the Reading screen the way the same list's rows do on
/// Browse's Surah tab. Uses [SurahListView] so the two never show different
/// data for the same surah.
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Listen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or number',
                prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(child: SurahListView(query: _query, tapToListen: true)),
        ],
      ),
    );
  }
}
