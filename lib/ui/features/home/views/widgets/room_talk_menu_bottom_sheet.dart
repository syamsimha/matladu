import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matladu_ai/core/constants/app_colors.dart';
import 'package:matladu_ai/core/constants/app_typography.dart';
import 'package:matladu_ai/data/models/room_model.dart';
import 'package:matladu_ai/data/services/room/i_room_service.dart';
import 'package:matladu_ai/ui/features/live_translation/views/live_translation_screen.dart';

/// Hamburger Menu displaying ONLY two options per reference specification:
/// 1. Create Room to Talk
/// 2. Join Room to Talk
class RoomTalkMenuBottomSheet extends StatelessWidget {
  final IRoomService roomService;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  const RoomTalkMenuBottomSheet({
    super.key,
    required this.roomService,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  static void show(
    BuildContext context, {
    required IRoomService roomService,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RoomTalkMenuBottomSheet(
        roomService: roomService,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: targetLanguageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppDarkColors.border : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppDarkColors.primary.withValues(alpha: 0.2) : AppColors.cardLightBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    color: isDark ? AppDarkColors.primary : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Talk Rooms',
                  style: AppTypography.displayMedium.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Connect two phones for synchronized real-time conversation.',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),

            // Option 1: Create Room to Talk
            _buildOptionCard(
              context: context,
              isDark: isDark,
              icon: Icons.meeting_room_rounded,
              iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              iconColor: isDark ? AppDarkColors.primary : AppColors.primary,
              title: 'Create Room to Talk',
              subtitle: 'Host a conversation room and generate a code for your peer.',
              onTap: () {
                Navigator.pop(context);
                _showCreateRoomDialog(context);
              },
            ),

            const SizedBox(height: 14),

            // Option 2: Join Room to Talk
            _buildOptionCard(
              context: context,
              isDark: isDark,
              icon: Icons.group_add_rounded,
              iconBgColor: isDark ? const Color(0xFF143026) : const Color(0xFFECFDF5),
              iconColor: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
              title: 'Join Room to Talk',
              subtitle: 'Enter an active room code shared by another speaker.',
              onTap: () {
                Navigator.pop(context);
                _showJoinRoomDialog(context);
              },
            ),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppDarkColors.surfaceSecondary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppDarkColors.border : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _CreateRoomDialog(
        roomService: roomService,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: targetLanguageCode,
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _JoinRoomDialog(
        roomService: roomService,
      ),
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  final IRoomService roomService;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  const _CreateRoomDialog({
    required this.roomService,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  RoomModel? _room;
  bool _isLoading = true;
  StreamSubscription<RoomModel>? _sub;

  @override
  void initState() {
    super.initState();
    _initRoom();
  }

  Future<void> _initRoom() async {
    final room = await widget.roomService.createRoom(
      sourceLanguageCode: widget.sourceLanguageCode,
      targetLanguageCode: widget.targetLanguageCode,
    );
    if (mounted) {
      setState(() {
        _room = room;
        _isLoading = false;
      });

      _sub = widget.roomService.roomStream.listen((updatedRoom) {
        if (mounted && updatedRoom.roomId == room.roomId) {
          setState(() {
            _room = updatedRoom;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: _isLoading
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppDarkColors.primary.withValues(alpha: 0.15) : AppColors.cardLightBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: isDark ? AppDarkColors.primary : AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Room Created',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this room code with the person you want to talk to:',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Big Room Code Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppDarkColors.surfaceSecondary : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppDarkColors.primary : AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _room?.roomId ?? '------',
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.0,
                          color: isDark ? AppDarkColors.primary : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Copy Code',
                        onPressed: () {
                          if (_room != null) {
                            Clipboard.setData(ClipboardData(text: _room!.roomId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Room code copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Connection Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _room?.isConnected == true
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                        : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _room?.isConnected == true
                            ? Icons.check_circle_rounded
                            : Icons.hourglass_top_rounded,
                        size: 16,
                        color: _room?.isConnected == true
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _room?.isConnected == true
                            ? 'Connected with Participant'
                            : 'Waiting for peer to join...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _room?.isConnected == true
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                              : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.roomService.leaveRoom();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveTranslationScreen(
                                roomId: _room?.roomId,
                                roomService: widget.roomService,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppDarkColors.primary : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Enter Room'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _JoinRoomDialog extends StatefulWidget {
  final IRoomService roomService;

  const _JoinRoomDialog({required this.roomService});

  @override
  State<_JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<_JoinRoomDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a room code.');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    final room = await widget.roomService.joinRoom(code);

    if (!mounted) return;

    if (room.state == RoomConnectionState.error) {
      setState(() {
        _isJoining = false;
        _errorMessage = room.errorMessage ?? 'Unable to join room. Please check the code.';
      });
    } else {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveTranslationScreen(
            roomId: room.roomId,
            roomService: widget.roomService,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppDarkColors.statusGreen.withValues(alpha: 0.15) : const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_add_rounded,
              color: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Join Room to Talk',
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the room code shared by the host:',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Code TextField
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: AppTypography.displayLarge.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. MTL-5829',
              hintStyle: TextStyle(
                color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                letterSpacing: 1.0,
                fontSize: 18,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: isDark ? AppDarkColors.surfaceSecondary : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppDarkColors.border : const Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppDarkColors.primary : AppColors.primary, width: 2),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _handleJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppDarkColors.primary : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Join Room'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
