enum ViewMode { grouped, flat }

enum SortColumn { none, type, key, summary, priority, assignee, status }

class ViewSettings {
  final ViewMode mode;
  final SortColumn column;
  final bool ascending;

  const ViewSettings({
    this.mode = ViewMode.grouped,
    this.column = SortColumn.none,
    this.ascending = true,
  });

  ViewSettings copyWith({
    ViewMode? mode,
    SortColumn? column,
    bool? ascending,
  }) =>
      ViewSettings(
        mode: mode ?? this.mode,
        column: column ?? this.column,
        ascending: ascending ?? this.ascending,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'column': column.name,
        'ascending': ascending,
      };

  static ViewSettings fromJson(Map<String, dynamic> json) => ViewSettings(
        mode: ViewMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => ViewMode.grouped,
        ),
        column: SortColumn.values.firstWhere(
          (c) => c.name == json['column'],
          orElse: () => SortColumn.none,
        ),
        ascending: (json['ascending'] as bool?) ?? true,
      );
}
