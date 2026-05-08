import 'package:json_annotation/json_annotation.dart';

enum ZoneType {
  @JsonValue('country') country,
  @JsonValue('region') region,
  @JsonValue('department') department,
  @JsonValue('park') park,
  @JsonValue('custom') custom,
}
