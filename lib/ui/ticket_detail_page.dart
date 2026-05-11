import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/adf.dart';
import '../data/jira_attachment.dart';
import '../data/jira_comment.dart';
import '../data/jira_issue.dart';
import '../data/jira_ticket.dart';
import '../data/jira_transition.dart';
import 'ticket_chrome.dart';

const double _wideThreshold = 800;
const Duration _pollInterval = Duration(seconds: 30);

class TicketDetailPage extends StatefulWidget {
  final JiraTicket initial;
  final String baseUrl;
  final Map<String, String> imageHeaders;
  final Future<JiraIssue> Function() onLoad;
  final Future<List<JiraTransition>> Function() onLoadTransitions;
  final Future<void> Function(JiraTransition) onApplyTransition;
  final Future<List<JiraComment>> Function() onLoadComments;
  final Future<JiraComment> Function(String) onPostComment;

  const TicketDetailPage({
    super.key,
    required this.initial,
    required this.baseUrl,
    this.imageHeaders = const {},
    required this.onLoad,
    required this.onLoadTransitions,
    required this.onApplyTransition,
    required this.onLoadComments,
    required this.onPostComment,
  });

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage>
    with WidgetsBindingObserver {
  JiraIssue? _issue;
  bool _loading = true;
  String? _error;

  List<JiraComment> _comments = const [];
  bool _commentsLoading = true;
  String? _commentsError;
  bool _posting = false;

  late JiraTicket _ticket;
  final TextEditingController _input = TextEditingController();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticket = widget.initial;
    _load();
    _loadComments().then((_) => _startPolling());
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_poll != null) return;
    _poll = Timer.periodic(_pollInterval, (_) => _pollComments());
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pollComments() async {
    if (_posting || _commentsLoading) return;
    try {
      final fresh = await widget.onLoadComments();
      if (!mounted) return;
      setState(() => _comments = _merged(_comments, fresh));
    } catch (_) {
      // Quiet failure — manual Refresh surfaces persistent errors.
    }
  }

  List<JiraComment> _merged(
    List<JiraComment> existing,
    List<JiraComment> fresh,
  ) {
    final byId = {for (final c in existing) c.id: c};
    for (final c in fresh) {
      byId[c.id] = c;
    }
    final order = <String>[
      for (final c in existing) c.id,
      for (final c in fresh)
        if (!existing.any((e) => e.id == c.id)) c.id,
    ];
    return [for (final id in order) byId[id]!];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final issue = await widget.onLoad();
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _ticket = issue.ticket;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final list = await widget.onLoadComments();
      if (!mounted) return;
      setState(() {
        _comments = list;
        _commentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentsLoading = false;
        _commentsError = '$e';
      });
    }
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await widget.onPostComment(text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, added];
        _posting = false;
      });
      _input.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      messenger.showSnackBar(SnackBar(content: Text('Post failed: $e')));
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _loadComments()]);
  }

  Future<void> _openInBrowser() async {
    final base = widget.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/browse/${_ticket.key}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ticket.key),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_new),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _issue == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _issue == null) {
      return Center(child: Text('Error: $_error'));
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        if (c.maxWidth >= _wideThreshold) return _wideLayout();
        return _narrowLayout();
      },
    );
  }

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _detailColumn(),
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(width: 360, child: _commentsPane()),
      ],
    );
  }

  Widget _narrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailColumn(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _commentsHeader(),
          const SizedBox(height: 8),
          ..._commentsBodyNarrow(),
        ],
      ),
    );
  }

  Widget _detailColumn() {
    final attachments = _issue?.attachments ?? const <JiraAttachment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: 16),
        _metaBar(context),
        const SizedBox(height: 16),
        _people(context),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1),
        ),
        _description(context),
        if (attachments.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _attachments(context, attachments),
        ],
      ],
    );
  }

  Widget _commentsPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _commentsHeader(),
        ),
        const Divider(height: 1),
        Expanded(child: _commentsList()),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _commentInput(),
        ),
      ],
    );
  }

  Widget _commentsHeader() {
    return Text(
      'Comments',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _commentsList() {
    if (_commentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_commentsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $_commentsError'),
      );
    }
    if (_comments.isEmpty) return _emptyComments();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _commentTile(_comments[i]),
    );
  }

  Widget _emptyComments() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No comments.',
        style: TextStyle(
          color: theme.colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  List<Widget> _commentsBodyNarrow() {
    if (_commentsLoading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_commentsError != null) {
      return [Text('Error: $_commentsError')];
    }
    final body = <Widget>[];
    if (_comments.isEmpty) {
      body.add(_emptyComments());
    } else {
      for (final c in _comments) {
        body.add(_commentTile(c));
        body.add(const SizedBox(height: 16));
      }
    }
    body.add(const Divider(height: 1));
    body.add(const SizedBox(height: 12));
    body.add(_commentInput());
    return body;
  }

  Widget _commentTile(JiraComment c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _commentTileHeader(c),
        const SizedBox(height: 4),
        _commentTileBody(c),
      ],
    );
  }

  Widget _commentTileHeader(JiraComment c) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            c.author.isEmpty ? '—' : c.author,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          _date(c.created),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _commentTileBody(JiraComment c) {
    final markdown = AdfMarkdown(c.body).text();
    if (markdown.isEmpty) return const Text('—');
    return MarkdownBody(
      data: markdown,
      selectable: true,
      onTapLink: (_, href, _) {
        if (href == null || href.isEmpty) return;
        launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
      },
    );
  }

  Widget _commentInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 4,
            enabled: !_posting,
            decoration: const InputDecoration(
              hintText: 'Add a comment',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _posting ? _postingSpinner() : _sendButton(),
      ],
    );
  }

  Widget _postingSpinner() {
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
      onPressed: _post,
      icon: const Icon(Icons.send),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 12),
          child: Tooltip(
            message: _ticket.issueType,
            child: Icon(_ticket.typeIcon, size: 24),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ticket.key, style: theme.textTheme.bodySmall),
              Text(
                _ticket.summary,
                style: theme.textTheme.headlineSmall,
              ),
              if (_ticket.parentKey.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '↳ ${_ticket.parentKey} · ${_ticket.parentSummary}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaBar(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _statusPill(theme),
        _chip(theme, _ticket.issueType),
        if (_ticket.priority.isNotEmpty)
          _chip(
            theme,
            _ticket.priority,
            icon: _ticket.priorityIcon,
            iconColor: _ticket.priorityColor,
          ),
      ],
    );
  }

  Widget _statusPill(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _onStatusTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _ticket.statusName.isEmpty ? '—' : _ticket.statusName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    ThemeData theme,
    String label, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }

  Widget _people(BuildContext context) {
    final theme = Theme.of(context);
    final issue = _issue;
    final reporter = issue?.reporter ?? '';
    final created = _date(issue?.created);
    final updated = _date(issue?.updated);
    final assignee = _ticket.assignee.isEmpty ? '—' : _ticket.assignee;
    return DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium ?? const TextStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(theme, 'Assignee', assignee),
          if (reporter.isNotEmpty) _kv(theme, 'Reporter', reporter),
          if (created.isNotEmpty || updated.isNotEmpty)
            _kv(
              theme,
              'Dates',
              [
                if (created.isNotEmpty) 'Created $created',
                if (updated.isNotEmpty) 'Updated $updated',
              ].join(' · '),
            ),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              key,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _date(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final t = raw.indexOf('T');
    return t > 0 ? raw.substring(0, t) : raw;
  }

  Widget _attachments(BuildContext context, List<JiraAttachment> all) {
    final theme = Theme.of(context);
    final images = all.where((a) => a.isImage).toList();
    final others = all.where((a) => !a.isImage).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments (${all.length})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final a in images) _imageTile(a)],
          ),
        if (images.isNotEmpty && others.isNotEmpty)
          const SizedBox(height: 12),
        if (others.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final a in others) _fileChip(a)],
          ),
      ],
    );
  }

  Widget _imageTile(JiraAttachment a) {
    final theme = Theme.of(context);
    final url = a.thumbnailUrl.isNotEmpty ? a.thumbnailUrl : a.contentUrl;
    return Tooltip(
      message: a.filename,
      child: InkWell(
        onTap: () => _openImage(a),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: _authImage(url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _fileChip(JiraAttachment a) {
    return ActionChip(
      avatar: const Icon(Icons.insert_drive_file_outlined, size: 18),
      label: Text(a.filename.isEmpty ? '—' : a.filename),
      onPressed: () => _openContentInBrowser(a),
    );
  }

  Widget _authImage(String url, {BoxFit fit = BoxFit.contain}) {
    return Image.network(
      url,
      fit: fit,
      headers: widget.imageHeaders,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Future<void> _openImage(JiraAttachment a) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 8,
              child: _authImage(a.contentUrl),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openContentInBrowser(JiraAttachment a) async {
    if (a.contentUrl.isEmpty) return;
    await launchUrl(Uri.parse(a.contentUrl), mode: LaunchMode.externalApplication);
  }

  Widget _description(BuildContext context) {
    final theme = Theme.of(context);
    final markdown = AdfMarkdown(_issue?.description).text();
    if (markdown.isEmpty) {
      return Text(
        'No description.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return MarkdownBody(
      data: markdown,
      selectable: true,
      imageBuilder: _descriptionImage,
      onTapLink: (_, href, _) {
        if (href == null || href.isEmpty) return;
        launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
      },
    );
  }

  Widget _descriptionImage(Uri uri, String? title, String? alt) {
    if (uri.scheme == 'jira-attachment') {
      final urls = _issue?.inlineImageUrls ?? const <String>[];
      final index = int.tryParse(uri.path) ?? -1;
      if (index < 0 || index >= urls.length) {
        return const Icon(Icons.broken_image_outlined);
      }
      return GestureDetector(
        onTap: () => _openInlineImage(urls[index]),
        child: _authImage(urls[index]),
      );
    }
    return Image.network(uri.toString());
  }

  Future<void> _openInlineImage(String url) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 8,
              child: _authImage(url),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onStatusTap() async {
    final messenger = ScaffoldMessenger.of(context);
    List<JiraTransition> transitions;
    try {
      transitions = await widget.onLoadTransitions();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Load failed: $e')));
      return;
    }
    if (!mounted) return;
    if (transitions.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No transitions available.')),
      );
      return;
    }
    final sorted = [...transitions]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selectedId = await showMenu<String>(
      context: context,
      position: _menuPosition(context),
      items: sorted
          .map((tr) => PopupMenuItem<String>(
                value: tr.id,
                child: Text(tr.name),
              ))
          .toList(),
    );
    if (selectedId == null) return;
    final selected = transitions.firstWhere((tr) => tr.id == selectedId);
    try {
      await widget.onApplyTransition(selected);
      if (!mounted) return;
      setState(() {
        _ticket = JiraTicket(
          key: _ticket.key,
          summary: _ticket.summary,
          statusName: selected.toStatus.isEmpty
              ? _ticket.statusName
              : selected.toStatus,
          statusCategory: selected.toStatusCategory.isEmpty
              ? _ticket.statusCategory
              : selected.toStatusCategory,
          issueType: _ticket.issueType,
          priority: _ticket.priority,
          assignee: _ticket.assignee,
          parentKey: _ticket.parentKey,
          parentSummary: _ticket.parentSummary,
        );
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Transition failed: $e')),
      );
    }
  }

  RelativeRect _menuPosition(BuildContext context) {
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return const RelativeRect.fromLTRB(0, 0, 0, 0);
    }
    final size = overlay.size;
    return RelativeRect.fromLTRB(48, 120, size.width - 240, 0);
  }
}
