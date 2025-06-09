import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';

class FavoriteButton extends StatelessWidget {
  final String plate;
  final FavoritesNotifier notifier;

  const FavoriteButton({
    super.key,
    required this.plate,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFavorite = notifier.isFavorite(plate);

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        color: isFavorite
            ? Colors.amber
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: isFavorite ? '取消收藏' : '加入收藏',
      onPressed: () {
        // 點擊按鈕時，呼叫 notifier 的方法來切換收藏狀態
        notifier.toggleFavorite(plate);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已將車牌 $plate ${isFavorite ? "移除" : "加入"}收藏'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: '復原',
              onPressed: () => notifier.toggleFavorite(plate),
            ),
          ),
        );
      },
    );
  }
}
