import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/jira_user.dart';
import '../data/mention_range.dart';
import '../data/mentioned_comment.dart';

class MentionField extends StatefulWidget {
  const MentionField({
    super.key,
    required this.enabled,
    required this.hintText,
    required this.onSearchUsers,
    required this.onSubmit,
  });

  final bool enabled;
  final String hintText;
  final Future<List<JiraUser>> Function(String query) onSearchUsers;
  final Future<void> Function(MentionedComment comment) onSubmit;

  @override
  State<MentionField> createState() => _MentionFieldState();
}

class _MentionFieldState extends State<MentionField> {
  final _MentionTextController _controller = _MentionTextController();
  final FocusNode _focus = FocusNode();
  final LayerLink _link = LayerLink();

  String _lastText = '';
  OverlayEntry? _popup;
  List<JiraUser> _suggestions = const [];
  int _highlighted = 0;
  int _atTriggerIndex = -1;
  String _activeQuery = '';
  Timer? _debounce;
  bool _submitting = false;

  static const _debounceDuration = Duration(milliseconds: 300);
  static const _popupWidth = 240.0;
  static const _popupMaxHeight = 240.0;
  static const _rowHeight = 36.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _dismissOverlay();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _field()),
          const SizedBox(width: 8),
          _submitting ? _spinner() : _sendButton(),
        ],
      ),
    );
  }

  Widget _field() {
    return Focus(
      onKeyEvent: _onKeyEvent,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        minLines: 1,
        maxLines: 4,
        enabled: widget.enabled && !_submitting,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _spinner() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _sendButton() {
    return IconButton(
      tooltip: 'Send',
      onPressed: widget.enabled && !_submitting ? _submit : null,
      icon: const Icon(Icons.send),
    );
  }

  Future<void> _submit({bool skipEmptyCheck = false}) async {
    if (!skipEmptyCheck) {
      final text = _controller.text.trim();
      if (text.isEmpty) return;
    }
    setState(() => _submitting = true);
    try {
      final comment = _ranges.isEmpty
          ? PlainComment(_controller.text) as MentionedComment
          : MentionedText(_controller.text, _ranges);
      await widget.onSubmit(comment);
      if (!mounted) return;
      _controller.clear();
      _controller.ranges = const [];
      _lastText = '';
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<MentionRange> get _ranges => _controller.ranges;
  set _ranges(List<MentionRange> next) => _controller.ranges = next;

  void _onTextChanged() {
    final newText = _controller.text;
    if (newText == _lastText) return;
    _ranges = _realignedRanges(_lastText, newText, _ranges);
    _lastText = newText;
    _detectActiveQuery();
  }

  static List<MentionRange> _realignedRanges(
    String oldText,
    String newText,
    List<MentionRange> ranges,
  ) {
    if (ranges.isEmpty) return const [];
    var prefix = 0;
    final maxPrefix = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix += 1;
    }
    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText[oldSuffix - 1] == newText[newSuffix - 1]) {
      oldSuffix -= 1;
      newSuffix -= 1;
    }
    final delta = newSuffix - oldSuffix;
    final next = <MentionRange>[];
    for (final r in ranges) {
      if (r.end <= prefix) {
        next.add(r);
      } else if (r.start >= oldSuffix) {
        next.add(MentionRange(
          accountId: r.accountId,
          displayName: r.displayName,
          start: r.start + delta,
          length: r.length,
        ));
      }
    }
    return next;
  }

  void _detectActiveQuery() {
    final sel = _controller.selection;
    if (!sel.isCollapsed) {
      _dismissOverlay();
      return;
    }
    final text = _controller.text;
    final caret = sel.baseOffset;
    if (caret < 0 || caret > text.length) {
      _dismissOverlay();
      return;
    }
    final atIndex = _findActiveAt(text, caret);
    if (atIndex < 0) {
      _dismissOverlay();
      return;
    }
    final query = text.substring(atIndex + 1, caret);
    _atTriggerIndex = atIndex;
    _activeQuery = query;
    _scheduleSearch(query);
  }

  int _findActiveAt(String text, int caret) {
    for (var i = caret - 1; i >= 0; i -= 1) {
      final ch = text[i];
      if (ch == '@') {
        final before = i == 0 ? null : text[i - 1];
        if (before == null || _isBoundary(before)) {
          final insideMention = _ranges.any((r) => r.start <= i && i < r.end);
          return insideMention ? -1 : i;
        }
        return -1;
      }
      if (_isWhitespace(ch)) return -1;
    }
    return -1;
  }

  bool _isBoundary(String c) => !RegExp(r'\w').hasMatch(c);
  bool _isWhitespace(String c) => c == ' ' || c == '\n' || c == '\t';

  void _scheduleSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    try {
      final users = await widget.onSearchUsers(query);
      if (!mounted) return;
      if (_activeQuery != query) return;
      _suggestions = users;
      _highlighted = 0;
      if (users.isEmpty) {
        _dismissOverlay();
      } else {
        _showOrUpdateOverlay();
      }
    } catch (_) {
      if (!mounted) return;
      _suggestions = const [];
      _dismissOverlay();
    }
  }

  void _showOrUpdateOverlay() {
    if (_popup == null) {
      _popup = OverlayEntry(builder: _buildOverlay);
      Overlay.of(context).insert(_popup!);
    } else {
      _popup!.markNeedsBuild();
    }
  }

  void _dismissOverlay() {
    _popup?.remove();
    _popup = null;
    _suggestions = const [];
    _highlighted = 0;
    _atTriggerIndex = -1;
    _activeQuery = '';
  }

  Widget _buildOverlay(BuildContext context) {
    final height = (_suggestions.length * _rowHeight).clamp(0.0, _popupMaxHeight);
    return Positioned(
      width: _popupWidth,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(0, -(height + 8)),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: height,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (_, i) => _suggestionRow(i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestionRow(int i) {
    final user = _suggestions[i];
    final selected = i == _highlighted;
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary.withAlpha(40)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _commitMention(user),
        child: SizedBox(
          height: _rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _commitMention(JiraUser u) {
    final atIndex = _atTriggerIndex;
    if (atIndex < 0) return;
    final queryEnd = atIndex + 1 + _activeQuery.length;
    final oldText = _controller.text;
    if (queryEnd > oldText.length) return;
    final mention = '@${u.displayName}';
    final newText = oldText.replaceRange(atIndex, queryEnd, '$mention ');
    final shift = (mention.length + 1) - (queryEnd - atIndex);
    final shifted = <MentionRange>[
      for (final r in _ranges)
        if (r.start >= queryEnd)
          MentionRange(
            accountId: r.accountId,
            displayName: r.displayName,
            start: r.start + shift,
            length: r.length,
          )
        else if (r.end <= atIndex)
          r,
    ];
    shifted.add(MentionRange(
      accountId: u.accountId,
      displayName: u.displayName,
      start: atIndex,
      length: mention.length,
    ));
    _ranges = shifted;
    _lastText = newText;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIndex + mention.length + 1),
    );
    _dismissOverlay();
    _focus.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_popup != null) {
      return _onOverlayKey(event);
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && _isSubmitModifierHeld()) {
      if (!widget.enabled || _submitting) return KeyEventResult.ignored;
      _submit(skipEmptyCheck: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      return _onBackspace();
    }
    return KeyEventResult.ignored;
  }

  bool _isSubmitModifierHeld() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight) ||
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  KeyEventResult _onOverlayKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _highlighted = (_highlighted + 1) % _suggestions.length;
      _popup?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _highlighted =
          (_highlighted - 1 + _suggestions.length) % _suggestions.length;
      _popup?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_suggestions.isNotEmpty && _highlighted < _suggestions.length) {
        _commitMention(_suggestions[_highlighted]);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _dismissOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onBackspace() {
    final caret = _controller.selection.baseOffset;
    if (!_controller.selection.isCollapsed || caret <= 0) {
      return KeyEventResult.ignored;
    }
    final atEdge = _ranges.where((r) => r.end == caret).toList();
    if (atEdge.isEmpty) return KeyEventResult.ignored;
    final hit = atEdge.first;
    final oldText = _controller.text;
    final newText = oldText.replaceRange(hit.start, hit.end, '');
    final next = <MentionRange>[
      for (final r in _ranges)
        if (r.start == hit.start && r.end == hit.end)
          // dropped
          ...const <MentionRange>[]
        else if (r.start >= hit.end)
          MentionRange(
            accountId: r.accountId,
            displayName: r.displayName,
            start: r.start - hit.length,
            length: r.length,
          )
        else if (r.end <= hit.start)
          r,
    ];
    _ranges = next;
    _lastText = newText;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: hit.start),
    );
    return KeyEventResult.handled;
  }
}

class _MentionTextController extends TextEditingController {
  List<MentionRange> ranges = const [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (ranges.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in sorted) {
      if (r.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, r.start)));
      }
      spans.add(TextSpan(
        text: text.substring(r.start, r.end),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      cursor = r.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: spans);
  }
}
