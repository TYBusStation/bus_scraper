import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/favorite_provider.dart';
import 'multi_live_osm_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  Future<void> _showAddGroupDialog(BuildContext context) async {
    final notifier = Provider.of<FavoritesNotifier>(context, listen: false);
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增群組'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '請輸入群組名稱'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (controller.text.trim().isNotEmpty) {
                notifier.addGroup(controller.text);
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  notifier.addGroup(controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameGroupDialog(
      BuildContext context, String oldName) async {
    final notifier = Provider.of<FavoritesNotifier>(context, listen: false);
    final controller = TextEditingController(text: oldName);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重新命名群組'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '請輸入新名稱'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  notifier.renameGroup(oldName, controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteGroupDialog(
      BuildContext context, String groupName) async {
    final notifier = Provider.of<FavoritesNotifier>(context, listen: false);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除 "$groupName" 群組嗎？群組內的車輛將會保留在其他收藏群組中。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () {
                notifier.removeGroup(groupName);
                Navigator.of(context).pop();
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        final groups = notifier.favoriteGroups;
        final bool hasNoFavorites = groups.values.every((list) => list.isEmpty);

        if (hasNoFavorites) {
          return const EmptyStateIndicator(
            icon: Icons.star_border_rounded,
            title: "尚未收藏任何車輛",
            subtitle: "請至「所有車輛」頁面點擊星星圖示\n將愛車加入收藏",
          );
        }

        final sortedGroupKeys = groups.keys.toList()
          ..sort((a, b) {
            if (a == FavoritesNotifier.defaultGroupName) return -1;
            if (b == FavoritesNotifier.defaultGroupName) return 1;
            return a.compareTo(b);
          });

        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: ElevatedButton.icon(
                onPressed: () => _showAddGroupDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('新增群組'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            for (final groupName in sortedGroupKeys)
              _buildGroupCard(context, notifier, groupName, groups[groupName]!),
          ],
        );
      },
    );
  }

  Widget _buildGroupCard(BuildContext context, FavoritesNotifier notifier,
      String groupName, List<String> plateList) {
    final carList = Static.carData
        .where((car) => plateList.contains(car.plate))
        .toList()
      ..sort((a, b) => a.plate.compareTo(b.plate));

    if (carList.isEmpty && groupName != FavoritesNotifier.defaultGroupName) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(groupName),
        initiallyExpanded: groupName == FavoritesNotifier.defaultGroupName,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '$groupName (${carList.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (groupName != FavoritesNotifier.defaultGroupName)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameGroupDialog(context, groupName);
                  } else if (value == 'delete') {
                    _showDeleteGroupDialog(context, groupName);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('重新命名'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('刪除群組'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
        children: [
          if (carList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MultiLiveOsmPage(plates: plateList),
                    ),
                  );
                },
                label: const Text('顯示此群組車輛動態'),
                icon: const Icon(Icons.map_outlined),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ),
          ...carList.map((car) {
            return CarListItem(car: car, showLiveButton: true);
          }).toList(),
        ],
      ),
    );
  }
}
