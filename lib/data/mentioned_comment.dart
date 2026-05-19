import 'mention_range.dart';

abstract interface class MentionedComment {
  Map<String, dynamic> adfDoc();
}

class PlainComment implements MentionedComment {
  const PlainComment(this._text);
  final String _text;

  @override
  Map<String, dynamic> adfDoc() {
    final paragraphs = <Map<String, dynamic>>[];
    for (final line in _text.split('\n')) {
      paragraphs.add(_paragraphOf(line));
    }
    return {
      'type': 'doc',
      'version': 1,
      'content': paragraphs,
    };
  }

  Map<String, dynamic> _paragraphOf(String line) {
    if (line.isEmpty) return const {'type': 'paragraph'};
    return {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': line},
      ],
    };
  }
}

class MentionedText implements MentionedComment {
  const MentionedText(this._text, this._ranges);
  final String _text;
  final List<MentionRange> _ranges;

  @override
  Map<String, dynamic> adfDoc() {
    if (_ranges.isEmpty) return PlainComment(_text).adfDoc();
    final sorted = [..._ranges]..sort((a, b) => a.start.compareTo(b.start));
    final paragraphs = <Map<String, dynamic>>[];
    var lineStart = 0;
    for (final line in _text.split('\n')) {
      paragraphs.add(_paragraphOf(line, lineStart, sorted));
      lineStart += line.length + 1;
    }
    return {
      'type': 'doc',
      'version': 1,
      'content': paragraphs,
    };
  }

  Map<String, dynamic> _paragraphOf(
    String line,
    int lineStart,
    List<MentionRange> sortedRanges,
  ) {
    final lineEnd = lineStart + line.length;
    final inLine = [
      for (final r in sortedRanges)
        if (r.start >= lineStart && r.end <= lineEnd) r,
    ];
    if (inLine.isEmpty) {
      if (line.isEmpty) return const {'type': 'paragraph'};
      return {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': line},
        ],
      };
    }
    return {
      'type': 'paragraph',
      'content': _nodesOf(line, lineStart, inLine),
    };
  }

  List<Map<String, dynamic>> _nodesOf(
    String line,
    int lineStart,
    List<MentionRange> ranges,
  ) {
    final nodes = <Map<String, dynamic>>[];
    var cursor = lineStart;
    for (final r in ranges) {
      if (r.start > cursor) {
        nodes.add({
          'type': 'text',
          'text': line.substring(cursor - lineStart, r.start - lineStart),
        });
      }
      nodes.add({
        'type': 'mention',
        'attrs': {'id': r.accountId, 'text': '@${r.displayName}'},
      });
      cursor = r.end;
    }
    final lineEnd = lineStart + line.length;
    if (cursor < lineEnd) {
      nodes.add({
        'type': 'text',
        'text': line.substring(cursor - lineStart),
      });
    }
    return nodes;
  }
}
