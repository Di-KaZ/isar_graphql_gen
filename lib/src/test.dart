import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'test.g.dart';

abstract class Fragment$User {
  String? id;
  int? somthing;
}

@collection
class CollectionUser extends Fragment$User {
  Id isar_id =
      Isar.autoIncrement; // you can also use id = null to auto increment
}

@embedded
class EmbededUser extends Fragment$User {}

@collection
class Event {
  Id isar_id = Isar.autoIncrement;
  List<EmbededUser?>? users;
}

////
///
///
///
///
///
///
