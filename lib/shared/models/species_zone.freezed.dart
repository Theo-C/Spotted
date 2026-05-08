// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'species_zone.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpeciesZone {

 String get speciesId; String get zoneId; Rarity get rarity;
/// Create a copy of SpeciesZone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeciesZoneCopyWith<SpeciesZone> get copyWith => _$SpeciesZoneCopyWithImpl<SpeciesZone>(this as SpeciesZone, _$identity);

  /// Serializes this SpeciesZone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeciesZone&&(identical(other.speciesId, speciesId) || other.speciesId == speciesId)&&(identical(other.zoneId, zoneId) || other.zoneId == zoneId)&&(identical(other.rarity, rarity) || other.rarity == rarity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,speciesId,zoneId,rarity);

@override
String toString() {
  return 'SpeciesZone(speciesId: $speciesId, zoneId: $zoneId, rarity: $rarity)';
}


}

/// @nodoc
abstract mixin class $SpeciesZoneCopyWith<$Res>  {
  factory $SpeciesZoneCopyWith(SpeciesZone value, $Res Function(SpeciesZone) _then) = _$SpeciesZoneCopyWithImpl;
@useResult
$Res call({
 String speciesId, String zoneId, Rarity rarity
});




}
/// @nodoc
class _$SpeciesZoneCopyWithImpl<$Res>
    implements $SpeciesZoneCopyWith<$Res> {
  _$SpeciesZoneCopyWithImpl(this._self, this._then);

  final SpeciesZone _self;
  final $Res Function(SpeciesZone) _then;

/// Create a copy of SpeciesZone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? speciesId = null,Object? zoneId = null,Object? rarity = null,}) {
  return _then(_self.copyWith(
speciesId: null == speciesId ? _self.speciesId : speciesId // ignore: cast_nullable_to_non_nullable
as String,zoneId: null == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String,rarity: null == rarity ? _self.rarity : rarity // ignore: cast_nullable_to_non_nullable
as Rarity,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeciesZone].
extension SpeciesZonePatterns on SpeciesZone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeciesZone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeciesZone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeciesZone value)  $default,){
final _that = this;
switch (_that) {
case _SpeciesZone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeciesZone value)?  $default,){
final _that = this;
switch (_that) {
case _SpeciesZone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String speciesId,  String zoneId,  Rarity rarity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeciesZone() when $default != null:
return $default(_that.speciesId,_that.zoneId,_that.rarity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String speciesId,  String zoneId,  Rarity rarity)  $default,) {final _that = this;
switch (_that) {
case _SpeciesZone():
return $default(_that.speciesId,_that.zoneId,_that.rarity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String speciesId,  String zoneId,  Rarity rarity)?  $default,) {final _that = this;
switch (_that) {
case _SpeciesZone() when $default != null:
return $default(_that.speciesId,_that.zoneId,_that.rarity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeciesZone implements SpeciesZone {
  const _SpeciesZone({required this.speciesId, required this.zoneId, required this.rarity});
  factory _SpeciesZone.fromJson(Map<String, dynamic> json) => _$SpeciesZoneFromJson(json);

@override final  String speciesId;
@override final  String zoneId;
@override final  Rarity rarity;

/// Create a copy of SpeciesZone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeciesZoneCopyWith<_SpeciesZone> get copyWith => __$SpeciesZoneCopyWithImpl<_SpeciesZone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeciesZoneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeciesZone&&(identical(other.speciesId, speciesId) || other.speciesId == speciesId)&&(identical(other.zoneId, zoneId) || other.zoneId == zoneId)&&(identical(other.rarity, rarity) || other.rarity == rarity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,speciesId,zoneId,rarity);

@override
String toString() {
  return 'SpeciesZone(speciesId: $speciesId, zoneId: $zoneId, rarity: $rarity)';
}


}

/// @nodoc
abstract mixin class _$SpeciesZoneCopyWith<$Res> implements $SpeciesZoneCopyWith<$Res> {
  factory _$SpeciesZoneCopyWith(_SpeciesZone value, $Res Function(_SpeciesZone) _then) = __$SpeciesZoneCopyWithImpl;
@override @useResult
$Res call({
 String speciesId, String zoneId, Rarity rarity
});




}
/// @nodoc
class __$SpeciesZoneCopyWithImpl<$Res>
    implements _$SpeciesZoneCopyWith<$Res> {
  __$SpeciesZoneCopyWithImpl(this._self, this._then);

  final _SpeciesZone _self;
  final $Res Function(_SpeciesZone) _then;

/// Create a copy of SpeciesZone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? speciesId = null,Object? zoneId = null,Object? rarity = null,}) {
  return _then(_SpeciesZone(
speciesId: null == speciesId ? _self.speciesId : speciesId // ignore: cast_nullable_to_non_nullable
as String,zoneId: null == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String,rarity: null == rarity ? _self.rarity : rarity // ignore: cast_nullable_to_non_nullable
as Rarity,
  ));
}


}

// dart format on
