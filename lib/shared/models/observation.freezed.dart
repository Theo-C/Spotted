// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'observation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Observation {

 String get id; String get userId; String get speciesId; String? get zoneId; DateTime get observedAt; double get latitude; double get longitude; String? get photoUrl; Map<String, dynamic>? get photoExifData; bool get isFirstForUser; int get pointsEarned; DateTime get createdAt;
/// Create a copy of Observation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ObservationCopyWith<Observation> get copyWith => _$ObservationCopyWithImpl<Observation>(this as Observation, _$identity);

  /// Serializes this Observation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Observation&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.speciesId, speciesId) || other.speciesId == speciesId)&&(identical(other.zoneId, zoneId) || other.zoneId == zoneId)&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&const DeepCollectionEquality().equals(other.photoExifData, photoExifData)&&(identical(other.isFirstForUser, isFirstForUser) || other.isFirstForUser == isFirstForUser)&&(identical(other.pointsEarned, pointsEarned) || other.pointsEarned == pointsEarned)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,speciesId,zoneId,observedAt,latitude,longitude,photoUrl,const DeepCollectionEquality().hash(photoExifData),isFirstForUser,pointsEarned,createdAt);

@override
String toString() {
  return 'Observation(id: $id, userId: $userId, speciesId: $speciesId, zoneId: $zoneId, observedAt: $observedAt, latitude: $latitude, longitude: $longitude, photoUrl: $photoUrl, photoExifData: $photoExifData, isFirstForUser: $isFirstForUser, pointsEarned: $pointsEarned, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ObservationCopyWith<$Res>  {
  factory $ObservationCopyWith(Observation value, $Res Function(Observation) _then) = _$ObservationCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String speciesId, String? zoneId, DateTime observedAt, double latitude, double longitude, String? photoUrl, Map<String, dynamic>? photoExifData, bool isFirstForUser, int pointsEarned, DateTime createdAt
});




}
/// @nodoc
class _$ObservationCopyWithImpl<$Res>
    implements $ObservationCopyWith<$Res> {
  _$ObservationCopyWithImpl(this._self, this._then);

  final Observation _self;
  final $Res Function(Observation) _then;

/// Create a copy of Observation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? speciesId = null,Object? zoneId = freezed,Object? observedAt = null,Object? latitude = null,Object? longitude = null,Object? photoUrl = freezed,Object? photoExifData = freezed,Object? isFirstForUser = null,Object? pointsEarned = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,speciesId: null == speciesId ? _self.speciesId : speciesId // ignore: cast_nullable_to_non_nullable
as String,zoneId: freezed == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String?,observedAt: null == observedAt ? _self.observedAt : observedAt // ignore: cast_nullable_to_non_nullable
as DateTime,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,photoExifData: freezed == photoExifData ? _self.photoExifData : photoExifData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isFirstForUser: null == isFirstForUser ? _self.isFirstForUser : isFirstForUser // ignore: cast_nullable_to_non_nullable
as bool,pointsEarned: null == pointsEarned ? _self.pointsEarned : pointsEarned // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Observation].
extension ObservationPatterns on Observation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Observation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Observation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Observation value)  $default,){
final _that = this;
switch (_that) {
case _Observation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Observation value)?  $default,){
final _that = this;
switch (_that) {
case _Observation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String speciesId,  String? zoneId,  DateTime observedAt,  double latitude,  double longitude,  String? photoUrl,  Map<String, dynamic>? photoExifData,  bool isFirstForUser,  int pointsEarned,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Observation() when $default != null:
return $default(_that.id,_that.userId,_that.speciesId,_that.zoneId,_that.observedAt,_that.latitude,_that.longitude,_that.photoUrl,_that.photoExifData,_that.isFirstForUser,_that.pointsEarned,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String speciesId,  String? zoneId,  DateTime observedAt,  double latitude,  double longitude,  String? photoUrl,  Map<String, dynamic>? photoExifData,  bool isFirstForUser,  int pointsEarned,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Observation():
return $default(_that.id,_that.userId,_that.speciesId,_that.zoneId,_that.observedAt,_that.latitude,_that.longitude,_that.photoUrl,_that.photoExifData,_that.isFirstForUser,_that.pointsEarned,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String speciesId,  String? zoneId,  DateTime observedAt,  double latitude,  double longitude,  String? photoUrl,  Map<String, dynamic>? photoExifData,  bool isFirstForUser,  int pointsEarned,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Observation() when $default != null:
return $default(_that.id,_that.userId,_that.speciesId,_that.zoneId,_that.observedAt,_that.latitude,_that.longitude,_that.photoUrl,_that.photoExifData,_that.isFirstForUser,_that.pointsEarned,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Observation implements Observation {
  const _Observation({required this.id, required this.userId, required this.speciesId, this.zoneId, required this.observedAt, required this.latitude, required this.longitude, this.photoUrl, final  Map<String, dynamic>? photoExifData, required this.isFirstForUser, required this.pointsEarned, required this.createdAt}): _photoExifData = photoExifData;
  factory _Observation.fromJson(Map<String, dynamic> json) => _$ObservationFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String speciesId;
@override final  String? zoneId;
@override final  DateTime observedAt;
@override final  double latitude;
@override final  double longitude;
@override final  String? photoUrl;
 final  Map<String, dynamic>? _photoExifData;
@override Map<String, dynamic>? get photoExifData {
  final value = _photoExifData;
  if (value == null) return null;
  if (_photoExifData is EqualUnmodifiableMapView) return _photoExifData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  bool isFirstForUser;
@override final  int pointsEarned;
@override final  DateTime createdAt;

/// Create a copy of Observation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ObservationCopyWith<_Observation> get copyWith => __$ObservationCopyWithImpl<_Observation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ObservationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Observation&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.speciesId, speciesId) || other.speciesId == speciesId)&&(identical(other.zoneId, zoneId) || other.zoneId == zoneId)&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&const DeepCollectionEquality().equals(other._photoExifData, _photoExifData)&&(identical(other.isFirstForUser, isFirstForUser) || other.isFirstForUser == isFirstForUser)&&(identical(other.pointsEarned, pointsEarned) || other.pointsEarned == pointsEarned)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,speciesId,zoneId,observedAt,latitude,longitude,photoUrl,const DeepCollectionEquality().hash(_photoExifData),isFirstForUser,pointsEarned,createdAt);

@override
String toString() {
  return 'Observation(id: $id, userId: $userId, speciesId: $speciesId, zoneId: $zoneId, observedAt: $observedAt, latitude: $latitude, longitude: $longitude, photoUrl: $photoUrl, photoExifData: $photoExifData, isFirstForUser: $isFirstForUser, pointsEarned: $pointsEarned, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ObservationCopyWith<$Res> implements $ObservationCopyWith<$Res> {
  factory _$ObservationCopyWith(_Observation value, $Res Function(_Observation) _then) = __$ObservationCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String speciesId, String? zoneId, DateTime observedAt, double latitude, double longitude, String? photoUrl, Map<String, dynamic>? photoExifData, bool isFirstForUser, int pointsEarned, DateTime createdAt
});




}
/// @nodoc
class __$ObservationCopyWithImpl<$Res>
    implements _$ObservationCopyWith<$Res> {
  __$ObservationCopyWithImpl(this._self, this._then);

  final _Observation _self;
  final $Res Function(_Observation) _then;

/// Create a copy of Observation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? speciesId = null,Object? zoneId = freezed,Object? observedAt = null,Object? latitude = null,Object? longitude = null,Object? photoUrl = freezed,Object? photoExifData = freezed,Object? isFirstForUser = null,Object? pointsEarned = null,Object? createdAt = null,}) {
  return _then(_Observation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,speciesId: null == speciesId ? _self.speciesId : speciesId // ignore: cast_nullable_to_non_nullable
as String,zoneId: freezed == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String?,observedAt: null == observedAt ? _self.observedAt : observedAt // ignore: cast_nullable_to_non_nullable
as DateTime,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,photoExifData: freezed == photoExifData ? _self._photoExifData : photoExifData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isFirstForUser: null == isFirstForUser ? _self.isFirstForUser : isFirstForUser // ignore: cast_nullable_to_non_nullable
as bool,pointsEarned: null == pointsEarned ? _self.pointsEarned : pointsEarned // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
