import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/jira.dart';
import '../data/jira_credentials.dart';
import '../data/jira_ticket.dart';
import 'ticket_detail_page.dart';
import 'ticket_window_args.dart';

/// The root of a spawned ticket window — its own [MaterialApp] hosting a
/// [TicketDetailPage] wired straight to Jira from the window's payload.
///
/// It owns no list to patch and reads no keychain: the credentials arrive in
/// [args], and every call goes through a fresh [Jira] over the wire.
class TicketWindow extends StatefulWidget {
  final TicketWindowArgs args;

  const TicketWindow({super.key, required this.args});

  @override
  State<TicketWindow> createState() => _TicketWindowState();
}

class _TicketWindowState extends State<TicketWindow> {
  static const _seed = Colors.indigo;

  final Jira _jira = Jira();
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  JiraCredentials get _credentials => widget.args.credentials;

  Map<String, String> get _imageHeaders {
    final auth = base64Encode(
      utf8.encode('${_credentials.email}:${_credentials.apiToken}'),
    );
    return {'Authorization': 'Basic $auth'};
  }

  TicketDetailPage _detailFor(JiraTicket ticket) => TicketDetailPage(
        initial: ticket,
        baseUrl: _credentials.baseUrl,
        imageHeaders: _imageHeaders,
        onLoad: () => _jira.issue(ticket, _credentials),
        onLoadTransitions: () => _jira.transitions(ticket, _credentials),
        onApplyTransition: (tr) =>
            _jira.transition(ticket, tr.id, _credentials),
        onLoadComments: () => _jira.comments(ticket, _credentials),
        onPostComment: (comment) =>
            _jira.postComment(ticket, comment, _credentials),
        onSearchUsers: (q) => _jira.searchUsers(q, _credentials),
        onOpenTicket: (t) => _navKey.currentState?.push(
          MaterialPageRoute(builder: (_) => _detailFor(t)),
        ),
        onUpdateDescription: (desc) =>
            _jira.updateDescription(ticket, desc, _credentials),
        onLoadAssignableUsers: (q) =>
            _jira.assignableUsers(ticket, _credentials, query: q),
        onChangeAssignee: (user) =>
            _jira.changeAssignee(ticket, user?.accountId, _credentials),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.args.ticketKey,
      navigatorKey: _navKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: _detailFor(
        JiraTicket(
          key: widget.args.ticketKey,
          summary: '',
          statusName: '',
          statusCategory: '',
          issueType: '',
        ),
      ),
    );
  }
}
