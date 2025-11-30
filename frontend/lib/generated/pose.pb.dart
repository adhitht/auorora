// This is a generated file - do not edit.
//
// Generated from pose.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PoseRequest extends $pb.GeneratedMessage {
  factory PoseRequest({
    $core.List<$core.int>? imageData,
    $core.List<$core.int>? newSkeletonData,
  }) {
    final result = create();
    if (imageData != null) result.imageData = imageData;
    if (newSkeletonData != null) result.newSkeletonData = newSkeletonData;
    return result;
  }

  PoseRequest._();

  factory PoseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PoseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PoseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pose'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'imageData', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'newSkeletonData', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PoseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PoseRequest copyWith(void Function(PoseRequest) updates) =>
      super.copyWith((message) => updates(message as PoseRequest))
          as PoseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PoseRequest create() => PoseRequest._();
  @$core.override
  PoseRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PoseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PoseRequest>(create);
  static PoseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get imageData => $_getN(0);
  @$pb.TagNumber(1)
  set imageData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasImageData() => $_has(0);
  @$pb.TagNumber(1)
  void clearImageData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get newSkeletonData => $_getN(1);
  @$pb.TagNumber(2)
  set newSkeletonData($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNewSkeletonData() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewSkeletonData() => $_clearField(2);
}

class PoseResponse extends $pb.GeneratedMessage {
  factory PoseResponse({
    $core.List<$core.int>? processedImageData,
  }) {
    final result = create();
    if (processedImageData != null)
      result.processedImageData = processedImageData;
    return result;
  }

  PoseResponse._();

  factory PoseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PoseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PoseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pose'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'processedImageData', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PoseResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PoseResponse copyWith(void Function(PoseResponse) updates) =>
      super.copyWith((message) => updates(message as PoseResponse))
          as PoseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PoseResponse create() => PoseResponse._();
  @$core.override
  PoseResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PoseResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PoseResponse>(create);
  static PoseResponse? _defaultInstance;

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
