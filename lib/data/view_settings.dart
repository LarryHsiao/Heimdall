enum ViewMode { grouped, flat }

enum SortColumn { none, type, key, summary, priority, assignee, status }

class ViewSettings {
  static const Map<SortColumn, double> defaultWidths = {
    SortColumn.type: 80,
    SortColumn.key: 110,
    SortColumn.priority: 90,
    SortColumn.assignee: 150,
    SortColumn.status: 140,
  };

  final ViewMode mode;
  final SortColumn column;
  final bool ascending;
  final Map<SortColumn, double> columnWidths;

  const ViewSettings({
    this.mode = ViewMode.grouped,
    this.column = SortColumn.none,
    this.ascending = true,
    this.columnWidths = defaultWidths,
  });

  double widthOf(SortColumn column) =>
      columnWidths[column] ?? defaultWidths[column] ?? 80;

  ViewSettings copyWith({
    ViewMode? mode,
    SortColumn? column,
    bool? ascending,
    Map<SortColumn, double>? columnWidths,
  }) =>
      ViewSettings(
        mode: mode ?? this.mode,
        column: column ?? this.column,
        ascending: ascending ?? this.ascending,
        columnWidths: columnWidths ?? this.columnWidths,
      );

  ViewSettings setWidth(SortColumn column, double width) {
    final next = Map<SortColumn, double>.from(columnWidths);
    next[column] = width;
    return copyWith(columnWidths: next);
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'column': column.name,
        'ascending': ascending,
        'widths': {
          for (final e in columnWidths.entries) e.key.name: e.value,
        },
      };

  static ViewSettings fromJson(Map<String, dynamic> json) {
    final widths = Map<SortColumn, double>.from(defaultWidths);
    final raw = (json['widths'] as Map?) ?? const {};
    raw.forEach((k, v) {
      final col = SortColumn.values.firstWhere(
        (c) => c.name == k,
        orElse: () => SortColumn.none,
      );
      if (col != SortColumn.none && v is num) {
        widths[col] = v.toDouble();
      }
    });
    return ViewSettings(
      mode: ViewMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ViewMode.grouped,
      ),
      column: SortColumn.values.firstWhere(
        (c) => c.name == json['column'],
        orElse: () => SortColumn.none,
      ),
      ascending: (json['ascending'] as bool?) ?? true,
      columnWidths: widths,
    );
  }
}
