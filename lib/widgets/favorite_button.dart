import 'package:bus_scraper/utils/formatter_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'favorite_provider.dart';

void _findPathsWithPlate(dynamic node, String plate, List<String> currentPath,
    List<List<String>> results) {
  if (node is List) {
    if (node.contains(plate)) {
      results.add(List.from(currentPath));
    }
  } else if (node is Map) {
    node.forEach((key, value) {
      _findPathsWithPlate(value, plate, [...currentPath, key], results);
    });
  }
}

Future<void> _showManageGroupsDialog(
    BuildContext context, FavoritesNotifier notifier, String plate) async {
  final List<List<String>> currentPaths = [];
  _findPathsWithPlate(notifier.data, plate, [], currentPaths);

  final Set<String> selectedPathStrings =
      currentPaths.map((p) => p.join(' > ')).toSet();

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('將 $plate 加入收藏'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notifier.data.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("請先在收藏頁面建立群組",
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ...notifier.data.entries.map((e) => _buildFolderOption(
                        context,
                        e.key,
                        e.value,
                        [],
                        selectedPathStrings,
                        setDialogState,
                        0)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final List<List<String>> finalPaths =
                      selectedPathStrings.map((s) => s.split(' > ')).toList();
                  notifier.updatePlateLocations(plate, finalPaths);
                  Navigator.of(context).pop();
                  FormatterUtils.showSnackbar(context, '已更新收藏');
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

Widget _buildFolderOption(
    BuildContext context,
    String key,
    dynamic value,
    List<String> parentPath,
    Set<String> selection,
    StateSetter setState,
    int depth) {
  final List<String> currentPath = [...parentPath, key];
  final String pathString = currentPath.join(' > ');
  final bool isLeaf = value is List;

  if (isLeaf) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.only(left: depth * 16.0),
      dense: true,
      title: Text(key),
      value: selection.contains(pathString),
      onChanged: (bool? checked) {
        setState(() {
          if (checked == true) {
            selection.add(pathString);
          } else {
            selection.remove(pathString);
          }
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  } else if (value is Map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.only(left: depth * 16.0 + 16.0, top: 8, bottom: 4),
          child: Text(
            key,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
        ),
        ...value.entries.map((e) => _buildFolderOption(context, e.key, e.value,
            currentPath, selection, setState, depth + 1)),
      ],
    );
  }
  return const SizedBox.shrink();
}

class FavoriteButton extends StatelessWidget {
  final String plate;

  const FavoriteButton({
    super.key,
    required this.plate,
  });

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
            _showManageGroupsDialog(context, notifier, plate);
          },
        );
      },
    );
  }
}

class FavoriteBtnMini extends StatelessWidget {
  final String plate;

  const FavoriteBtnMini({super.key, required this.plate});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        final bool isFavorite = notifier.isFavorite(plate);
        return InkWell(
          onTap: () => _showManageGroupsDialog(context, notifier, plate),
          child: Icon(isFavorite ? Icons.star : Icons.star_border, size: 16),
        );
      },
    );
  }
}
