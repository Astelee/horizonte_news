import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Centraliza o NOME de verdade e "pendura" o selo/botões à direita dele.
///
/// Por que existe: com `Row(mainAxisSize: min)` o que fica centralizado é o
/// conjunto nome + selo, então o nome parece puxado para a esquerda. Aqui o
/// nome fica entre dois `Expanded` iguais (o da esquerda vazio), então o
/// centro do nome coincide sempre com o centro da coluna/avatar, e o
/// [trailing] ocupa só a metade direita, continuando clicável.
///
/// [trailingWidth] é a largura aproximada do [trailing] (sem o [gap]); serve
/// só para limitar o tamanho do nome e evitar overflow. Se errar por pouco,
/// o nome continua centralizado.
class CenteredNameRow extends StatelessWidget {
  final Widget name;
  final Widget? trailing;
  final double trailingWidth;
  final double gap;

  const CenteredNameRow({
    Key? key,
    required this.name,
    this.trailing,
    this.trailingWidth = 0,
    this.gap = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = trailing;
    if (t == null) return Center(child: name);

    return LayoutBuilder(
      builder: (context, c) {
        // Sem largura limitada não dá para espelhar: cai no layout simples.
        if (!c.hasBoundedWidth) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: name),
              Padding(padding: EdgeInsets.only(left: gap), child: t),
            ],
          );
        }
        final reserve = gap + trailingWidth + 2;
        final maxName = math.max(0.0, c.maxWidth - 2 * reserve);
        return Row(
          children: [
            const Expanded(child: SizedBox.shrink()),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxName),
              child: name,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(padding: EdgeInsets.only(left: gap), child: t),
              ),
            ),
          ],
        );
      },
    );
  }
}