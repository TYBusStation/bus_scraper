import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'favorite_provider.dart';

class FavoriteButton extends StatelessWidget {
  final String plate;

  const FavoriteButton({
    super.key,
    required this.plate,
  });

  Future<void> _showManageGroupsDialog(
      BuildContext context, FavoritesNotifier notifier) async {
    final Set<String> originalGroups = notifier.getGroupsForPlate(plate);
    final Set<String> selectedGroups = Set.from(originalGroups);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final groupKeys = notifier.favoriteGroups.keys.toList();

            return AlertDialog(
              title: Text('將 $plate 加入收藏'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groupKeys.length,
                  itemBuilder: (context, index) {
                    final groupName = groupKeys[index];
                    return CheckboxListTile(
                      title: Text(groupName),
                      value: selectedGroups.contains(groupName),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedGroups.add(groupName);
                          } else {
                            selectedGroups.remove(groupName);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (!setEquals(originalGroups, selectedGroups)) {
                      notifier.updatePlateGroups(plate, selectedGroups);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已更新車牌 $plate 的收藏狀態'),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: '復原',
                            onPressed: () => notifier.updatePlateGroups(
                                plate, originalGroups),
                          ),
                          showCloseIcon: true,
                        ),
                      );
                    }
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        final bool isFavorite = notifier.isFavorite(plate);

        return IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite
                ? Colors.amber
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: '管理收藏',
          onPressed: () {
            _showManageGroupsDialog(context, notifier);
          },
        );
      },
    );
  }
}
