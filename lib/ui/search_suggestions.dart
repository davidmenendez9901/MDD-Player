import 'dart:async';
import 'dart:convert';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:songtube/providers/content_provider.dart';
import 'package:songtube/ui/animations/animated_icon.dart';
import 'package:songtube/ui/text_styles.dart';

class SearchSuggestions extends StatefulWidget {
  const SearchSuggestions({
    required this.onSearch,
    required this.searchQuery,
    super.key});
  final Function(String) onSearch;
  final String searchQuery;

  @override
  State<SearchSuggestions> createState() => _SearchSuggestionsState();
}

class _SearchSuggestionsState extends State<SearchSuggestions> {

  // Search Client
  http.Client client = http.Client();

  // Debounce + request bookkeeping so we don't fire an HTTP request on every
  // keystroke: the query is only queried after a short pause, and stale
  // in-flight responses are ignored via an incrementing request id.
  Timer? _debounce;
  int _requestId = 0;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    if (widget.searchQuery.isNotEmpty) {
      _scheduleFetch(widget.searchQuery);
    }
  }

  @override
  void didUpdateWidget(covariant SearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      if (widget.searchQuery.isEmpty) {
        _debounce?.cancel();
        if (_suggestions.isNotEmpty) {
          setState(() => _suggestions = []);
        }
      } else {
        _scheduleFetch(widget.searchQuery);
      }
    }
  }

  void _scheduleFetch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final requestId = ++_requestId;
    try {
      final response = await client.get(
        Uri.https('suggestqueries.google.com', '/complete/search', {
          'client': 'firefox',
          'q': query,
        }),
        headers: {
          'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            '(KHTML, like Gecko) Chrome/86.0.4240.111 Safari/537.36',
          'accept-language': 'en-US,en;q=1.0',
        },
      );
      // Ignore the response if a newer request has started or we're gone
      if (!mounted || requestId != _requestId) {
        return;
      }
      final map = jsonDecode(response.body);
      final List<String> results = [];
      for (final result in map[1]) {
        results.add(result as String);
      }
      setState(() {
        _suggestions = results;
      });
    } catch (_) {
      // Keep the previous suggestions on network/parse errors
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ContentProvider contentProvider = Provider.of(context);
    List<String> searchHistory = contentProvider.getSearchHistory();
    final List<String> suggestionsList = widget.searchQuery.isEmpty ? const [] : _suggestions;
    final List<String> finalList = suggestionsList + searchHistory;
    return Container(
      color: Theme.of(context).cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 0),
        itemExtent: 40,
        itemCount: finalList.length,
        itemBuilder: (context, index) {
          String item = finalList[index];
          return ListTile(
            contentPadding: const EdgeInsets.all(8).copyWith(right: 4, top: 0),
            title: Text(
              item,
              style: smallTextStyle(context, opacity: 0.8),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
            leading: SizedBox(
              width: 40,
              height: 40,
              child: AppAnimatedIcon(
                suggestionsList.contains(item)
                  ? Ionicons.search_outline
                  : EvaIcons.clockOutline,
                size: 20,
              ),
            ),
            trailing: !suggestionsList.contains(item) ? IconButton(
              icon: const AppAnimatedIcon(Icons.clear, size: 18, opacity: 0.6,),
              onPressed: () {
                contentProvider.removeStringfromSearchHistory(index);
              },
            ) : null,
            onTap: () {
              contentProvider.addStringtoSearchHistory(item);
              widget.onSearch(item);
            },
          );
        },
      ),
    );
  }
}