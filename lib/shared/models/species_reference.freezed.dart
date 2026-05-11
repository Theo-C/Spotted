// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'species_reference.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpeciesReference {

 String get scientificName; String get commonName;/// Clé de catégorie (birds/mammals/reptiles/bats) — matche
/// `categories.icon` côté DB.
 String get categoryKey;/// Rareté suggérée (common/rare/epic/legendary). Indicative —
/// l'user peut l'ajuster selon son territoire.
 String? get rarityHint; String get description; String get tips;/// URL d'une photo d'illustration (CC, depuis iNaturalist).
 String? get photoUrl;
/// Create a copy of SpeciesReference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeciesReferenceCopyWith<SpeciesReference> get copyWith => _$SpeciesReferenceCopyWithImpl<SpeciesReference>(this as SpeciesReference, _$identity);

  /// Serializes this SpeciesReference to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeciesReference&&(identical(other.scientificName, scientificName) || other.scientificName == scientificName)&&(identical(other.commonName, commonName) || other.commonName == commonName)&&(identical(other.categoryKey, categoryKey) || other.categoryKey == categoryKey)&&(identical(other.rarityHint, rarityHint) || other.rarityHint == rarityHint)&&(identical(other.description, description) || other.description == description)&&(identical(other.tips, tips) || other.tips == tips)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scientificName,commonName,categoryKey,rarityHint,description,tips,photoUrl);

@override
String toString() {
  return 'SpeciesReference(scientificName: $scientificName, commonName: $commonName, categoryKey: $categoryKey, rarityHint: $rarityHint, description: $description, tips: $tips, photoUrl: $photoUrl)';
}


}

/// @nodoc
abstract mixin class $SpeciesReferenceCopyWith<$Res>  {
  factory $SpeciesReferenceCopyWith(SpeciesReference value, $Res Function(SpeciesReference) _then) = _$SpeciesReferenceCopyWithImpl;
@useResult
$Res call({
 String scientificName, String commonName, String categoryKey, String? rarityHint, String description, String tips, String? photoUrl
});




}
/// @nodoc
class _$SpeciesReferenceCopyWithImpl<$Res>
    implements $SpeciesReferenceCopyWith<$Res> {
  _$SpeciesReferenceCopyWithImpl(this._self, this._then);

  final SpeciesReference _self;
  final $Res Function(SpeciesReference) _then;

/// Create a copy of SpeciesReference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scientificName = null,Object? commonName = null,Object? categoryKey = null,Object? rarityHint = freezed,Object? description = null,Object? tips = null,Object? photoUrl = freezed,}) {
  return _then(_self.copyWith(
scientificName: null == scientificName ? _self.scientificName : scientificName // ignore: cast_nullable_to_non_nullable
as String,commonName: null == commonName ? _self.commonName : commonName // ignore: cast_nullable_to_non_nullable
as String,categoryKey: null == categoryKey ? _self.categoryKey : categoryKey // ignore: cast_nullable_to_non_nullable
as String,rarityHint: freezed == rarityHint ? _self.rarityHint : rarityHint // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tips: null == tips ? _self.tips : tips // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeciesReference].
extension SpeciesReferencePatterns on SpeciesReference {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeciesReference value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeciesReference() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeciesReference value)  $default,){
final _that = this;
switch (_that) {
case _SpeciesReference():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeciesReference value)?  $default,){
final _that = this;
switch (_that) {
case _SpeciesReference() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String scientificName,  String commonName,  String categoryKey,  String? rarityHint,  String description,  String tips,  String? photoUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeciesReference() when $default != null:
return $default(_that.scientificName,_that.commonName,_that.categoryKey,_that.rarityHint,_that.description,_that.tips,_that.photoUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String scientificName,  String commonName,  String categoryKey,  String? rarityHint,  String description,  String tips,  String? photoUrl)  $default,) {final _that = this;
switch (_that) {
case _SpeciesReference():
return $default(_that.scientificName,_that.commonName,_that.categoryKey,_that.rarityHint,_that.description,_that.tips,_that.photoUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String scientificName,  String commonName,  String categoryKey,  String? rarityHint,  String description,  String tips,  String? photoUrl)?  $default,) {final _that = this;
switch (_that) {
case _SpeciesReference() when $default != null:
return $default(_that.scientificName,_that.commonName,_that.categoryKey,_that.rarityHint,_that.description,_that.tips,_that.photoUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeciesReference implements SpeciesReference {
  const _SpeciesReference({required this.scientificName, required this.commonName, required this.categoryKey, this.rarityHint, required this.description, required this.tips, this.photoUrl});
  factory _SpeciesReference.fromJson(Map<String, dynamic> json) => _$SpeciesReferenceFromJson(json);

@override final  String scientificName;
@override final  String commonName;
/// Clé de catégorie (birds/mammals/reptiles/bats) — matche
/// `categories.icon` côté DB.
@override final  String categoryKey;
/// Rareté suggérée (common/rare/epic/legendary). Indicative —
/// l'user peut l'ajuster selon son territoire.
@override final  String? rarityHint;
@override final  String description;
@override final  String tips;
/// URL d'une photo d'illustration (CC, depuis iNaturalist).
@override final  String? photoUrl;

/// Create a copy of SpeciesReference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeciesReferenceCopyWith<_SpeciesReference> get copyWith => __$SpeciesReferenceCopyWithImpl<_SpeciesReference>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeciesReferenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeciesReference&&(identical(other.scientificName, scientificName) || other.scientificName == scientificName)&&(identical(other.commonName, commonName) || other.commonName == commonName)&&(identical(other.categoryKey, categoryKey) || other.categoryKey == categoryKey)&&(identical(other.rarityHint, rarityHint) || other.rarityHint == rarityHint)&&(identical(other.description, description) || other.description == description)&&(identical(other.tips, tips) || other.tips == tips)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scientificName,commonName,categoryKey,rarityHint,description,tips,photoUrl);

@override
String toString() {
  return 'SpeciesReference(scientificName: $scientificName, commonName: $commonName, categoryKey: $categoryKey, rarityHint: $rarityHint, description: $description, tips: $tips, photoUrl: $photoUrl)';
}


}

/// @nodoc
abstract mixin class _$SpeciesReferenceCopyWith<$Res> implements $SpeciesReferenceCopyWith<$Res> {
  factory _$SpeciesReferenceCopyWith(_SpeciesReference value, $Res Function(_SpeciesReference) _then) = __$SpeciesReferenceCopyWithImpl;
@override @useResult
$Res call({
 String scientificName, String commonName, String categoryKey, String? rarityHint, String description, String tips, String? photoUrl
});




}
/// @nodoc
class __$SpeciesReferenceCopyWithImpl<$Res>
    implements _$SpeciesReferenceCopyWith<$Res> {
  __$SpeciesReferenceCopyWithImpl(this._self, this._then);

  final _SpeciesReference _self;
  final $Res Function(_SpeciesReference) _then;

/// Create a copy of SpeciesReference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scientificName = null,Object? commonName = null,Object? categoryKey = null,Object? rarityHint = freezed,Object? description = null,Object? tips = null,Object? photoUrl = freezed,}) {
  return _then(_SpeciesReference(
scientificName: null == scientificName ? _self.scientificName : scientificName // ignore: cast_nullable_to_non_nullable
as String,commonName: null == commonName ? _self.commonName : commonName // ignore: cast_nullable_to_non_nullable
as String,categoryKey: null == categoryKey ? _self.categoryKey : categoryKey // ignore: cast_nullable_to_non_nullable
as String,rarityHint: freezed == rarityHint ? _self.rarityHint : rarityHint // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tips: null == tips ? _self.tips : tips // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
