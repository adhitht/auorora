// This is a generated file - do not edit.
//
// Generated from relighting.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class RelightRequest extends $pb.GeneratedMessage {
  factory RelightRequest({
    $core.List<$core.int>? imageData,
    $core.List<$core.int>? lightmapData,
  }) {
    final result = create();
    if (imageData != null) result.imageData = imageData;
    if (lightmapData != null) result.lightmapData = lightmapData;
    return result;
  }

  RelightRequest._();

  factory RelightRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelightRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelightRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relighting'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'imageData', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'lightmapData', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelightRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelightRequest copyWith(void Function(RelightRequest) updates) =>
      super.copyWith((message) => updates(message as RelightRequest))
          as RelightRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelightRequest create() => RelightRequest._();
  @$core.override
  RelightRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelightRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelightRequest>(create);
  static RelightRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get imageData => $_getN(0);
  @$pb.TagNumber(1)
  set imageData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasImageData() => $_has(0);
  @$pb.TagNumber(1)
  void clearImageData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get lightmapData => $_getN(1);
  @$pb.TagNumber(2)
  set lightmapData($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLightmapData() => $_has(1);
  @$pb.TagNumber(2)
  void clearLightmapData() => $_clearField(2);
}

class RelightResponse extends $pb.GeneratedMessage {
  factory RelightResponse({
    $core.List<$core.int>? processedImageData,
  }) {
    final result = create();
    if (processedImageData != null)
      result.processedImageData = processedImageData;
    return result;
  }

  RelightResponse._();

  factory RelightResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelightResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelightResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relighting'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'processedImageData', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelightResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelightResponse copyWith(void Function(RelightResponse) updates) =>
      super.copyWith((message) => updates(message as RelightResponse))
          as RelightResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelightResponse create() => RelightResponse._();
  @$core.override
  RelightResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelightResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelightResponse>(create);
  static RelightResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get processedImageData => $_getN(0);
  @$pb.TagNumber(1)
  set processedImageData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProcessedImageData() => $_has(0);
  @$pb.TagNumber(1)
  void clearProcessedImageData() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
