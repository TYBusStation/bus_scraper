import 'package:json_annotation/json_annotation.dart';

part 'favorite_folder.g.dart';

@JsonSerializable(explicitToJson: true)
class FavoriteFolder {
  String name;
  List<String> plates;
  List<FavoriteFolder> subFolders;

  FavoriteFolder({
    required this.name,
    List<String>? plates, // 接收可選的列表
    List<FavoriteFolder>? subFolders, // 接收可選的列表
  })  : this.plates = plates ?? [],
        // 如果是 null，則建立新的可變列表 []
        this.subFolders = subFolders ?? []; // 如果是 null，則建立新的可變列表 []

  factory FavoriteFolder.fromJson(Map<String, dynamic> json) =>
      _$FavoriteFolderFromJson(json);

  Map<String, dynamic> toJson() => _$FavoriteFolderToJson(this);

  List<String> getAllPlatesRecursive() {
    final Set<String> all = Set.from(plates);
    for (var sub in subFolders) {
      all.addAll(sub.getAllPlatesRecursive());
    }
    return all.toList();
  }
}
