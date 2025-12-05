import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/loading_overlay.dart';
import 'conversation_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late List<Map<String, Object>> users;
  late Map<String, List<Map<String, Object>>> userMessages;

  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedUserName;
  static const double _compactBreakpoint = 900;

  @override
  void initState() {
    super.initState();
    final conversationSeeds = [
      [
        {'fromMe': false, 'text': 'Hey, are you free tomorrow?'},
        {'fromMe': true, 'text': 'I might be — what time were you thinking?'},
        {'fromMe': false, 'text': 'Mid afternoon. We could do the 3 PM call.'},
        {'fromMe': true, 'text': 'Works for me. I\'ll be online.'},
        {
          'fromMe': false,
          'text': 'Great — also, check the pool docs when you have time.',
        },
      ],
      [
        {'fromMe': false, 'text': 'Thanks for the report earlier.'},
        {'fromMe': true, 'text': 'Anytime! Do you need help with the follow-ups?'},
        {
          'fromMe': false,
          'text': 'Yes, can you summarize the main blockers?'
        },
        {'fromMe': true, 'text': 'Sure, I\'ll send a quick doc.'},
      ],
      [
        {'fromMe': false, 'text': 'Have you seen the new branding guide?'},
        {'fromMe': true, 'text': 'Not yet, please drop it in the channel.'},
        {'fromMe': false, 'text': 'Shared to your drive — looks great!'},
        {'fromMe': true, 'text': 'Love the gradient updates.'},
      ],
      [
        {'fromMe': false, 'text': 'Can you review the event trigger?'
        },
        {'fromMe': true, 'text': 'On it, I will check after lunch.'},
        {'fromMe': false, 'text': 'Thanks, the customer is eager.'},
        {
          'fromMe': true,
          'text': 'I\'m almost done with the test coverage.'
        },
      ],
    ];
    users = [];
    userMessages = {};
    for (var i = 0; i < 12; i++) {
      final userName = 'User ${i + 1}';
      final seed = conversationSeeds[i % conversationSeeds.length];
      userMessages[userName] = seed
          .map((m) => Map<String, Object>.from(m))
          .toList();
      users.add({
        'name': userName,
        'last': userMessages[userName]!.last['text'] as String,
      });
    }
    _selectedUserName = users.first['name'] as String;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, Object>> _conversationFor(String userName) {
    return userMessages[userName] ?? <Map<String, Object>>[];
  }

  void _updateLastPreview(String userName, String text) {
    final index = users.indexWhere((u) => u['name'] == userName);
    if (index >= 0) {
      users[index]['last'] = text;
    }
  }

  void _sendMessage() {
    final text = _controller.text.trimRight();
    if (text.isEmpty) return;
    final activeUserName = _selectedUserName ?? users.first['name'] as String;
    _handleSendForUser(activeUserName, text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _handleSendForUser(String userName, String text) {
    if (text.isEmpty) return;
    setState(() {
      _addMessageToConversation(userName, text);
    });
  }

  void _addMessageToConversation(String userName, String text) {
    final conversation = userMessages[userName];
    if (conversation == null) return;
    conversation.add({'fromMe': true, 'text': text});
    _updateLastPreview(userName, text);
  }

  void _handleUserTap(String userName, bool isCompact) {
    setState(() {
      _selectedUserName = userName;
    });
    if (isCompact) {
      _openConversationDetail(userName);
    }
  }

  void _openConversationDetail(String userName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationDetailScreen(
          userName: userName,
          messages: _conversationFor(userName),
          onSend: (message) => _handleSendForUser(userName, message),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final searchQuery = _searchQuery.trim().toLowerCase();
    final filteredUsers = users.where((u) {
      if (searchQuery.isEmpty) return true;
      final name = (u['name'] as String).toLowerCase();
      final last = (u['last'] as String).toLowerCase();
      final matchesUserInfo = name.contains(searchQuery) || last.contains(searchQuery);
      final matchesChatContext = _conversationFor(u['name'] as String).any((m) {
        final text = (m['text'] as String).toLowerCase();
        return text.contains(searchQuery);
      });
      return matchesUserInfo || matchesChatContext;
    }).toList();
    final activeUserName = _selectedUserName ?? users.first['name'] as String;
    final activeConversation = _conversationFor(activeUserName);

    return LoadingOverlay(
      isLoading: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < _compactBreakpoint;
            if (isCompact) {
              return _buildUserListPane(theme, colors, filteredUsers, activeUserName, isCompact);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildUserListPane(theme, colors, filteredUsers, activeUserName, isCompact),
                Expanded(
                  child: _buildConversationPane(theme, colors, activeUserName, activeConversation),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserListPane(ThemeData theme, ColorScheme colors,
      List<Map<String, Object>> filteredUsers, String activeUserName, bool isCompact) {
    return Container(
      width: isCompact ? double.infinity : 320,
      color: theme.cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(
                          Icons.search,
                          color: colors.onSurface.withOpacity(0.6),
                        ),
                        hintText: 'Search users & chats',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: colors.onSurface.withOpacity(0.06), height: 1),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      'No users or chat matches yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, __) => Divider(
                      color: colors.onSurface.withOpacity(0.04),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final u = filteredUsers[index];
                      final userName = u['name'] as String;
                      final isSelected = userName == activeUserName;
                      final titleStyle = theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? colors.primary : null,
                      );
                      final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colors.primary.withOpacity(0.8)
                            : colors.onSurface.withOpacity(0.6),
                      );
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: colors.primary.withOpacity(0.12),
                        tileColor: isSelected ? colors.primary.withOpacity(0.08) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? colors.primary : Colors.transparent,
                            width: isSelected ? 1.5 : 0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? colors.primary : Colors.blueGrey,
                          child: Text(
                            userName.split(' ').last,
                            style: TextStyle(
                              color: isSelected ? colors.onPrimary : null,
                            ),
                          ),
                        ),
                        title: Text(
                          userName,
                          style: titleStyle,
                        ),
                        subtitle: Text(
                          u['last'] as String,
                          style: subtitleStyle,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '2:13 PM',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? colors.primary : colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: isSelected ? colors.primary : Colors.red,
                              child: Text(
                                '3',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected ? colors.onPrimary : colors.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          _handleUserTap(userName, isCompact);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationPane(ThemeData theme, ColorScheme colors, String activeUserName,
      List<Map<String, Object>> activeConversation) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x1AFFFFFF)),
              ),
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    activeUserName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  color: colors.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListView.builder(
                itemCount: activeConversation.length,
                itemBuilder: (context, index) {
                  final m = activeConversation[index];
                  final fromMe = m['fromMe'] as bool;
                  final bubbleColor = fromMe ? colors.primary : colors.surfaceVariant;
                  final textColor = fromMe ? colors.onPrimary : colors.onSurface;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment:
                          fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!fromMe) const SizedBox(width: 8),
                        if (!fromMe)
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colors.primaryContainer,
                            child: Icon(Icons.person, size: 14),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(fromMe ? 12 : 2),
                                bottomRight: Radius.circular(fromMe ? 2 : 12),
                              ),
                            ),
                            child: Text(
                              m['text'] as String,
                              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                            ),
                          ),
                        ),
                        if (fromMe) const SizedBox(width: 8),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                top: BorderSide(color: colors.onSurface.withOpacity(0.06)),
              ),
            ),
            constraints: const BoxConstraints(minHeight: 80),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.add,
                      color: colors.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: KeyboardListener(
                      focusNode: _keyboardFocusNode,
                      onKeyEvent: (KeyEvent event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          final isShift = HardwareKeyboard.instance.isShiftPressed;
                          if (isShift) {
                            final sel = _controller.selection;
                            final text = _controller.text;
                            final newText = text.replaceRange(sel.start, sel.end, '\n');
                            final newPos = sel.start + 1;
                            _controller.text = newText;
                            _controller.selection =
                                TextSelection.collapsed(offset: newPos);
                          } else {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_controller.text.endsWith('\n')) {
                                _controller.text = _controller.text.trimRight();
                              }
                              _sendMessage();
                            });
                          }
                        }
                      },
                      child: TextField(
                        focusNode: _focusNode,
                        controller: _controller,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 20,
                        textAlignVertical: TextAlignVertical.center,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Write a message...',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colors.onSurface.withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colors.primary,
                              width: 1.5,
                            ),
                          ),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(Icons.send, color: colors.onPrimary),
                    splashRadius: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
