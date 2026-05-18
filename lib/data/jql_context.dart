import 'jql_token.dart';

class JqlContext {
  final String fieldName;
  final String partial;

  const JqlContext({
    required this.fieldName,
    required this.partial,
  });

  bool get isValueContext => fieldName.isNotEmpty;
}

JqlContext jqlContextAt(String text, int cursor) {
  final partial = lastTokenAt(text, cursor);
  final tokenStart = cursor - partial.length;

  var i = _skipWhitespaceBackward(text, tokenStart - 1);
  if (i < 0 || !_isOperatorChar(text[i])) {
    return JqlContext(fieldName: '', partial: partial);
  }

  while (i >= 0 && _isOperatorChar(text[i])) {
    i--;
  }
  i = _skipWhitespaceBackward(text, i);
  if (i < 0) {
    return JqlContext(fieldName: '', partial: partial);
  }

  final fieldEnd = i + 1;
  while (i >= 0 && !_isWhitespace(text[i]) && !_isOperatorChar(text[i])) {
    i--;
  }
  final fieldName = text.substring(i + 1, fieldEnd);
  if (fieldName.isEmpty) {
    return JqlContext(fieldName: '', partial: partial);
  }
  return JqlContext(fieldName: fieldName, partial: partial);
}

int _skipWhitespaceBackward(String text, int from) {
  var i = from;
  while (i >= 0 && _isWhitespace(text[i])) {
    i--;
  }
  return i;
}

bool _isWhitespace(String ch) =>
    ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';

bool _isOperatorChar(String ch) =>
    ch == '=' || ch == '<' || ch == '>' || ch == '~' || ch == '!';
