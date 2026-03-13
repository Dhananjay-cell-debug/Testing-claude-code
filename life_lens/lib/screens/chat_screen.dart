import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ai/life_coach_service.dart';
import '../database/database_helper.dart';
import '../models/chat_message.dart';
import '../utils/constants.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _coach = LifeCoachService();
  final _db = DatabaseHelper();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _loadingBrief = false;

  // Quick prompt suggestions
  final _suggestions = [
    "Plan my tomorrow",
    "What's my biggest weakness this week?",
    "Give me a 7-day improvement plan",
    "Why am I so distracted lately?",
    "What should I focus on this month?",
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await _db.getTodaysChatMessages();
    setState(() => _messages = msgs);
    if (msgs.isEmpty) {
      _generateDailyBrief();
    } else {
      _scrollToBottom();
    }
  }

  Future<void> _generateDailyBrief() async {
    setState(() => _loadingBrief = true);
    try {
      final brief = await _coach.generateDailyBrief();
      final msg = ChatMessage(
        id: 'brief_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: brief,
        timestamp: DateTime.now(),
        isDaily: true,
      );
      await _db.saveChatMessage(msg);
      setState(() {
        _messages.add(msg);
        _loadingBrief = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loadingBrief = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.tertiary,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _inputController.clear();
    _focusNode.unfocus();

    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    await _db.saveChatMessage(userMsg);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _coach.chat(_messages, text.trim());
      final assistantMsg = ChatMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );
      await _db.saveChatMessage(assistantMsg);
      setState(() {
        _messages.add(assistantMsg);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.tertiary,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _messages.isEmpty && _loadingBrief
                ? _buildLoadingState()
                : _buildMessageList(),
          ),
          if (_messages.isEmpty && !_loadingBrief) _buildSuggestions(),
          if (_messages.isNotEmpty && !_isLoading) _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: AppSizes.padding,
        right: AppSizes.padding,
        bottom: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI COACH', style: AppTextStyles.label.copyWith(color: AppColors.primary)),
                Text('Your personal life strategist', style: AppTextStyles.body.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 20),
              tooltip: 'New brief',
              onPressed: _loadingBrief || _isLoading ? null : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: Text('New Daily Brief', style: TextStyle(color: AppColors.textPrimary)),
                    content: Text('Start fresh with a new brief for today?', style: TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Yes', style: TextStyle(color: AppColors.primary))),
                    ],
                  ),
                );
                if (confirm == true) _generateDailyBrief();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 20),
          Text('Analyzing your day...', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Building your personal brief', style: AppTextStyles.body),
          const SizedBox(height: 24),
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildMessage(_messages[i]);
      },
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'), backgroundColor: AppColors.scoreHigh),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isUser ? null : Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildMessageContent(msg, isUser),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg, bool isUser) {
    if (isUser) {
      return Text(
        msg.content,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      );
    }
    // For assistant messages, render markdown-like formatting
    return _MarkdownText(text: msg.content, isDaily: msg.isDaily);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 200),
                const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _sendMessage(_suggestions[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _suggestions[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.padding,
        right: AppSizes.padding,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask your coach anything...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_inputController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.border : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isLoading ? AppColors.textMuted : Colors.black,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple markdown-like text renderer
class _MarkdownText extends StatelessWidget {
  final String text;
  final bool isDaily;

  const _MarkdownText({required this.text, this.isDaily = false});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
        final content = line.substring(2, line.length - 2);
        spans.add(TextSpan(
          text: content,
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14),
        ));
      } else if (line.contains('**')) {
        // Inline bold
        final parts = line.split('**');
        for (int j = 0; j < parts.length; j++) {
          if (j.isOdd) {
            spans.add(TextSpan(
              text: parts[j],
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
            ));
          } else {
            spans.add(TextSpan(text: parts[j], style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6)));
          }
        }
      } else if (line.startsWith('🎯') || line.startsWith('⚡') || line.startsWith('📖') ||
                 line.startsWith('✅') || line.startsWith('⚠️') || line.startsWith('🗓')) {
        spans.add(TextSpan(
          text: line,
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14, height: 1.8),
        ));
      } else if (line.startsWith('---')) {
        spans.add(TextSpan(text: '─────────────────', style: TextStyle(color: AppColors.border, fontSize: 12)));
      } else if (line.startsWith('• ') || line.startsWith('- ')) {
        spans.add(TextSpan(
          text: line,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
        ));
      } else if (line.trim().isEmpty) {
        spans.add(const TextSpan(text: ''));
      } else {
        spans.add(TextSpan(
          text: line,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
      ),
    );
  }
}
