import 'package:json_annotation/json_annotation.dart';

part 'favorite_folder.g.dart';

@JsonSerializable(explicitToJson: true)
class FavoriteFolder {
  String name;
  List<String> plates;
  List<FavoriteFolder> subFolders;

  FavoriteFolder({
    required this.name,
    List<String>? plates,
    List<FavoriteFolder>? subFolders,
  })
      : this.plates = plates ?? [],
        this.subFolders = subFolders ?? [];

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
