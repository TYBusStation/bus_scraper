// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_folder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FavoriteFolder _$FavoriteFolderFromJson(Map<String, dynamic> json) =>
    FavoriteFolder(
      name: json['name'] as String,
      plates:
          (json['plates'] as List<dynamic>?)?.map((e) => e as String).toList(),
      subFolders: (json['subFolders'] as List<dynamic>?)
          ?.map((e) => FavoriteFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FavoriteFolderToJson(FavoriteFolder instance) =>
    <String, dynamic>{
      'name': instance.name,
      'plates': instance.plates,
      'subFolders': instance.subFolders.map((e) => e.toJson()).toList(),
    };
