import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/app_notification_service.dart';

/// Sino de notificações com badge de não lidas, para usar no AppBar
/// das telas principais (ver home_screen.dart). Por padrão usa o
/// mesmo formato "quadrado com cantos arredondados, transparente até
/// tocar" do resto dos ícones do AppBar (ver _NeoIconButton em
/// home_screen.dart) — passe [circular]: true para o visual em
/// círculo translúcido, usado em contextos fora do AppBar principal.
class NotificationBell extends StatefulWidget {
  final double size;
  final bool circular;

  const NotificationBell({
    Key? key,
    this.size = 38,
    this.circular = false,
  }) : super(key: key);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: AppNotificationService.watchUnreadCount(),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            Navigator.of(context).pushNamed(AppRoutes.notifications);
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: widget.circular
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.circular ? null : BorderRadius.circular(10),
              color: widget.circular
                  ? Colors.black.withOpacity(0.35)
                  : (_pressed
                      ? AppColors.primaryOrange.withOpacity(0.2)
                      : Colors.transparent),
              border: Border.all(
                color: widget.circular
                    ? AppColors.primaryOrange.withOpacity(0.25)
                    : (_pressed
                        ? AppColors.primaryOrange.withOpacity(0.5)
                        : Colors.transparent),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  unread > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  color: _pressed && !widget.circular
                      ? AppColors.primaryOrange
                      : Colors.white,
                  size: widget.size * 0.58,
                ),
                if (unread > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.backgroundDark, width: 1.5),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}