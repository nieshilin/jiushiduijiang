import 'package:flutter/material.dart';

import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/models/chat_message.dart';

/// 文字消息收发面板 — 底部弹出 Sheet
class MessagePanel extends StatefulWidget {
  final List<ChatMessage> messages;
  final String localDeviceName;
  final Function(String) onSend;

  const MessagePanel({
    super.key,
    required this.messages,
    required this.localDeviceName,
    required this.onSend,
  });

  @override
  State<MessagePanel> createState() => _MessagePanelState();
}

class _MessagePanelState extends State<MessagePanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSend = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final show = _inputController.text.trim().isNotEmpty;
      if (show != _showSend) {
        setState(() => _showSend = show);
      }
    });
  }

  @override
  void didUpdateWidget(MessagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新消息到达时滚动到底部
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: WalkieTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: WalkieTheme.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WalkieTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 18, color: WalkieTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  '群组消息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: WalkieTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.messages.length} 条',
                  style: const TextStyle(
                    fontSize: 12,
                    color: WalkieTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: WalkieTheme.divider),
          // 消息列表
          Expanded(
            child: widget.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(widget.messages[index]);
                    },
                  ),
          ),
          // 输入栏
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 40,
            color: WalkieTheme.textMuted,
          ),
          const SizedBox(height: 10),
          const Text(
            '暂无消息',
            style: TextStyle(
              fontSize: 13,
              color: WalkieTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '发送一条消息试试',
            style: TextStyle(
              fontSize: 12,
              color: WalkieTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _buildAvatar(msg.senderName, false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 发送者名称 + 时间
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe)
                      Text(
                        msg.senderName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WalkieTheme.accent,
                        ),
                      ),
                    if (!isMe) const SizedBox(width: 6),
                    Text(
                      msg.timeString,
                      style: const TextStyle(
                        fontSize: 11,
                        color: WalkieTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 消息内容
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? WalkieTheme.accent.withValues(alpha: 0.15)
                        : WalkieTheme.surfaceElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 14),
                    ),
                    border: Border.all(
                      color: isMe
                          ? WalkieTheme.accent.withValues(alpha: 0.3)
                          : WalkieTheme.border,
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe
                          ? WalkieTheme.textPrimary
                          : WalkieTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildAvatar(msg.senderName, true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, bool isMe) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe
            ? WalkieTheme.accent.withValues(alpha: 0.2)
            : WalkieTheme.surfaceElevated,
        border: Border.all(
          color: isMe
              ? WalkieTheme.accent.withValues(alpha: 0.4)
              : WalkieTheme.border,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isMe ? WalkieTheme.accent : WalkieTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: WalkieTheme.surface,
          border: Border(
            top: BorderSide(color: WalkieTheme.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: WalkieTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: WalkieTheme.border),
                ),
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: WalkieTheme.textPrimary,
                  ),
                  maxLines: null,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: TextStyle(
                        fontSize: 14, color: WalkieTheme.textMuted),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showSend ? _send : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showSend
                      ? WalkieTheme.accent
                      : WalkieTheme.surfaceElevated,
                  border: Border.all(
                    color: _showSend
                        ? WalkieTheme.accent
                        : WalkieTheme.border,
                  ),
                ),
                child: Icon(
                  Icons.send,
                  size: 18,
                  color: _showSend
                      ? WalkieTheme.lcdText
                      : WalkieTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
