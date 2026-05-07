import 'package:flutter/material.dart';

import '../data/jira_ticket.dart';

extension JiraTicketChrome on JiraTicket {
  bool get isSubtask {
    final t = issueType.toLowerCase();
    return t == 'sub-task' || t == 'subtask';
  }

  IconData get typeIcon {
    switch (issueType.toLowerCase()) {
      case 'bug':
        return Icons.bug_report_outlined;
      case 'story':
        return Icons.bookmark_outline;
      case 'task':
        return Icons.check_box_outlined;
      case 'epic':
        return Icons.flag_outlined;
      case 'sub-task':
      case 'subtask':
        return Icons.subdirectory_arrow_right;
      default:
        return Icons.circle_outlined;
    }
  }

  IconData get priorityIcon {
    switch (priority.toLowerCase()) {
      case 'highest':
        return Icons.keyboard_double_arrow_up;
      case 'high':
        return Icons.keyboard_arrow_up;
      case 'medium':
        return Icons.drag_handle;
      case 'low':
        return Icons.keyboard_arrow_down;
      case 'lowest':
        return Icons.keyboard_double_arrow_down;
      default:
        return Icons.remove;
    }
  }

  Color get priorityColor {
    switch (priority.toLowerCase()) {
      case 'highest':
        return Colors.red.shade700;
      case 'high':
        return Colors.red.shade400;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue.shade400;
      case 'lowest':
        return Colors.blue.shade700;
      default:
        return Colors.grey;
    }
  }
}
