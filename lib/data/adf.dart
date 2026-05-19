Map<String, dynamic> flipTaskItem(Map<String, dynamic> adf, int targetIndex) {
  var counter = 0;
  Map<String, dynamic> walk(Map<String, dynamic> node) {
    if ((node['type'] as String?) == 'taskItem') {
      final hit = counter == targetIndex;
      counter++;
      if (!hit) return node;
      final attrs = Map<String, dynamic>.from(
        (node['attrs'] as Map<String, dynamic>?) ?? const {},
      );
      final state = (attrs['state'] as String?) ?? 'TODO';
      attrs['state'] = state == 'DONE' ? 'TODO' : 'DONE';
      return {...node, 'attrs': attrs};
    }
    final content = node['content'];
    if (content is! List) return node;
    final next = <dynamic>[];
    for (final c in content) {
      next.add(c is Map<String, dynamic> ? walk(c) : c);
    }
    return {...node, 'content': next};
  }
  return walk(adf);
}

class AdfMarkdown {
  AdfMarkdown(this._doc);

  final Map<String, dynamic>? _doc;
  int _imageIndex = 0;

  String text() {
    final doc = _doc;
    if (doc == null) return '';
    _imageIndex = 0;
    final content = _children(doc);
    return _blocks(content).trimRight();
  }

  String _blocks(List<dynamic> nodes) {
    final out = StringBuffer();
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i] as Map<String, dynamic>;
      final block = _block(node);
      if (block.isEmpty) continue;
      out.write(block);
      if (i < nodes.length - 1) out.write('\n\n');
    }
    return out.toString();
  }

  String _block(Map<String, dynamic> node) {
    switch (node['type'] as String? ?? '') {
      case 'paragraph':
        return _inlines(_children(node));
      case 'heading':
        return _heading(node);
      case 'bulletList':
        return _bulletList(node);
      case 'orderedList':
        return _orderedList(node);
      case 'codeBlock':
        return _codeBlock(node);
      case 'blockquote':
        return _blockquote(node);
      case 'rule':
        return '---';
      case 'panel':
        return _panel(node);
      case 'mediaSingle':
        return _mediaSingle(node);
      case 'mediaGroup':
        return _mediaGroup(node);
      case 'taskList':
        return _taskList(node);
      default:
        return _inlines(_children(node));
    }
  }

  String _taskList(Map<String, dynamic> node) {
    final lines = <String>[];
    for (final c in _children(node)) {
      final line = _taskItem(c as Map<String, dynamic>);
      if (line.isNotEmpty) lines.add(line);
    }
    return lines.join('\n');
  }

  String _taskItem(Map<String, dynamic> node) {
    if ((node['type'] as String?) != 'taskItem') return '';
    final state = (_attrs(node)['state'] as String?) ?? 'TODO';
    final mark = state == 'DONE' ? 'x' : ' ';
    final body = _inlines(_children(node));
    return '- [$mark] $body';
  }

  String _mediaSingle(Map<String, dynamic> node) {
    final children = _children(node);
    if (children.isEmpty) return '';
    return _mediaImage(children.first as Map<String, dynamic>);
  }

  String _mediaGroup(Map<String, dynamic> node) {
    final lines = <String>[];
    for (final c in _children(node)) {
      final line = _mediaImage(c as Map<String, dynamic>);
      if (line.isNotEmpty) lines.add(line);
    }
    return lines.join('\n\n');
  }

  String _mediaImage(Map<String, dynamic> node) {
    if ((node['type'] as String?) != 'media') return '';
    return _mediaRef(node);
  }

  String _mediaRef(Map<String, dynamic> node) {
    final attrs = _attrs(node);
    final id = (attrs['id'] as String?) ?? '';
    if (id.isEmpty) return '';
    final alt = (attrs['alt'] as String?) ?? '';
    final index = _imageIndex++;
    return '![$alt](jira-attachment:$index)';
  }

  String _heading(Map<String, dynamic> node) {
    final level = (_attrs(node)['level'] as int?) ?? 1;
    final hashes = '#' * level.clamp(1, 6);
    return '$hashes ${_inlines(_children(node))}';
  }

  String _bulletList(Map<String, dynamic> node) {
    final items = _children(node)
        .map((c) => _listItem(c as Map<String, dynamic>, '- '))
        .toList();
    return items.join('\n');
  }

  String _orderedList(Map<String, dynamic> node) {
    final start = (_attrs(node)['order'] as int?) ?? 1;
    final children = _children(node);
    final lines = <String>[];
    for (var i = 0; i < children.length; i++) {
      final marker = '${start + i}. ';
      lines.add(_listItem(children[i] as Map<String, dynamic>, marker));
    }
    return lines.join('\n');
  }

  String _listItem(Map<String, dynamic> node, String marker) {
    final body = _blocks(_children(node));
    final lines = body.split('\n');
    if (lines.isEmpty) return marker.trimRight();
    final pad = ' ' * marker.length;
    final head = '$marker${lines.first}';
    final tail = lines.skip(1).map((l) => l.isEmpty ? l : '$pad$l');
    return [head, ...tail].join('\n');
  }

  String _codeBlock(Map<String, dynamic> node) {
    final lang = (_attrs(node)['language'] as String?) ?? '';
    final body = _children(node)
        .map((c) => (c as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
    return '```$lang\n$body\n```';
  }

  String _blockquote(Map<String, dynamic> node) {
    final body = _blocks(_children(node));
    return body.split('\n').map((l) => '> $l').join('\n');
  }

  String _panel(Map<String, dynamic> node) {
    final kind = (_attrs(node)['panelType'] as String?) ?? 'note';
    final body = _blocks(_children(node));
    final lead = '> **${kind[0].toUpperCase()}${kind.substring(1)}**';
    final lines = body.split('\n').map((l) => '> $l');
    return [lead, ...lines].join('\n');
  }

  String _inlines(List<dynamic> nodes) {
    final out = StringBuffer();
    for (final raw in nodes) {
      final node = raw as Map<String, dynamic>;
      out.write(_inline(node));
    }
    return out.toString();
  }

  String _inline(Map<String, dynamic> node) {
    switch (node['type'] as String? ?? '') {
      case 'text':
        return _text(node);
      case 'hardBreak':
        return '  \n';
      case 'mention':
        final raw = (_attrs(node)['text'] as String?)?.trim() ?? '';
        final label = raw.isEmpty ? '@user' : raw;
        return '**$label**';
      case 'emoji':
        return (_attrs(node)['text'] as String?) ??
            (_attrs(node)['shortName'] as String?) ??
            '';
      case 'inlineCard':
        final url = (_attrs(node)['url'] as String?) ?? '';
        return url.isEmpty ? '' : '<$url>';
      case 'status':
      case 'date':
        return (_attrs(node)['text'] as String?) ?? '';
      case 'mediaInline':
        return _mediaRef(node);
      default:
        return _inlines(_children(node));
    }
  }

  String _text(Map<String, dynamic> node) {
    var out = (node['text'] as String?) ?? '';
    final marks = (node['marks'] as List?) ?? const [];
    for (final m in marks) {
      out = _mark(m as Map<String, dynamic>, out);
    }
    return out;
  }

  String _mark(Map<String, dynamic> mark, String inner) {
    switch (mark['type'] as String? ?? '') {
      case 'strong':
        return '**$inner**';
      case 'em':
        return '*$inner*';
      case 'code':
        return '`$inner`';
      case 'strike':
        return '~~$inner~~';
      case 'underline':
        return '<u>$inner</u>';
      case 'link':
        final href = (_attrs(mark)['href'] as String?) ?? '';
        return href.isEmpty ? inner : '[$inner]($href)';
      default:
        return inner;
    }
  }

  Map<String, dynamic> _attrs(Map<String, dynamic> node) =>
      (node['attrs'] as Map<String, dynamic>?) ?? const {};

  List<dynamic> _children(Map<String, dynamic> node) =>
      (node['content'] as List?) ?? const [];
}
