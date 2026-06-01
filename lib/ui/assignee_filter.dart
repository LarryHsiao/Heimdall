/// A chosen set of assignees to narrow the ticket table by.
///
/// An empty selection means "all assignees". The empty string stands for
/// the unassigned bucket. The filter is immutable — toggling or pruning
/// yields a new instance.
class AssigneeFilter {
  final Set<String> selected;

  const AssigneeFilter([this.selected = const {}]);

  bool get isEmpty => selected.isEmpty;

  bool accepts(String assignee) =>
      selected.isEmpty || selected.contains(assignee);

  bool has(String name) => selected.contains(name);

  AssigneeFilter toggled(String name) {
    final next = Set<String>.from(selected);
    if (!next.add(name)) next.remove(name);
    return AssigneeFilter(next);
  }

  AssigneeFilter pruned(Set<String> valid) =>
      AssigneeFilter(selected.where(valid.contains).toSet());
}
