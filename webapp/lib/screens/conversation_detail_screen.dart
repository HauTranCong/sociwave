import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/loading_overlay.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String userName;
  final List<Map<String, Object>> messages;
  final ValueChanged<String> onSend;

  const ConversationDetailScreen({
    super.key,
    required this.userName,
    required this.messages,
    required this.onSend,
  });

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trimRight();
    if (text.isEmpty) return;
    widget.onSend(text);
    setState(() {});
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LoadingOverlay(
      isLoading: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: colors.onSurface,
          elevation: 0,
          title: Text(widget.userName),
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: ListView.builder(
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final m = widget.messages[index];
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
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: textColor),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: KeyboardListener(
                        focusNode: _keyboardFocusNode,
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter) {
                            final isShift =
                                HardwareKeyboard.instance.isShiftPressed;
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
                                _handleSend();
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
                      onPressed: _handleSend,
                      icon: Icon(Icons.send, color: colors.onPrimary),
                      splashRadius: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
