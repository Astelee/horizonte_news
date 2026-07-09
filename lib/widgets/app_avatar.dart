import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../models/avatar_catalog.dart';

class AppAvatar extends StatelessWidget {
  final String? avatarId;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppAvatar({
    Key? key,
    required this.avatarId,
    this.size = 44,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarCatalog.byId(avatarId);

    final content = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1A1A),
        border: showBorder
            ? Border.all(
                color: borderColor ?? const Color(0xFFFF6B00),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.2),
            blurRadius: size * 0.2,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: _SvgAvatar(url: avatar.networkUrl, size: size),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

// ═══════════════════════════════════════════════════════════════════
// SVG com cache manual via FutureBuilder + http
// ═══════════════════════════════════════════════════════════════════
class _SvgAvatar extends StatefulWidget {
  final String url;
  final double size;

  const _SvgAvatar({required this.url, required this.size});

  @override
  State<_SvgAvatar> createState() => _SvgAvatarState();
}

class _SvgAvatarState extends State<_SvgAvatar> {
  // Cache estático em memória — persiste enquanto o app estiver aberto
  static final Map<String, String> _cache = {};

  late Future<String> _svgFuture;

  @override
  void initState() {
    super.initState();
    _svgFuture = _loadSvg(widget.url);
  }

  Future<String> _loadSvg(String url) async {
    if (_cache.containsKey(url)) return _cache[url]!;
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final svg = response.body;
      _cache[url] = svg;
      return svg;
    }
    throw Exception('Falha ao carregar avatar');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _svgFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            width: widget.size,
            height: widget.size,
            color: const Color(0xFF1A1A1A),
            child: Center(
              child: SizedBox(
                width: widget.size * 0.35,
                height: widget.size * 0.35,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFFFF6B00).withOpacity(0.6),
                ),
              ),
            ),
          );
        }

        if (snap.hasError || !snap.hasData) {
          return Container(
            width: widget.size,
            height: widget.size,
            color: const Color(0xFF1A1A1A),
            child: Icon(
              Icons.person_rounded,
              color: const Color(0xFFFF6B00).withOpacity(0.5),
              size: widget.size * 0.5,
            ),
          );
        }

        return SvgPicture.string(
          snap.data!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
