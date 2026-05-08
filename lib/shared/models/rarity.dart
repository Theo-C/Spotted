import 'package:json_annotation/json_annotation.dart';

enum Rarity {
  @JsonValue('common') common,
  @JsonValue('rare') rare,
  @JsonValue('epic') epic,
  @JsonValue('legendary') legendary,
}
