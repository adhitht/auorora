// This is a generated file - do not edit.
//
// Generated from pose.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use poseRequestDescriptor instead')
const PoseRequest$json = {
  '1': 'PoseRequest',
  '2': [
    {'1': 'image_data', '3': 1, '4': 1, '5': 12, '10': 'imageData'},
    {
      '1': 'new_skeleton_data',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'newSkeletonData'
    },
    {'1': 'num_steps', '3': 3, '4': 1, '5': 5, '10': 'numSteps'},
    {
      '1': 'controlnet_conditioning',
      '3': 4,
      '4': 1,
      '5': 2,
      '10': 'controlnetConditioning'
    },
    {'1': 'strength', '3': 5, '4': 1, '5': 2, '10': 'strength'},
  ],
};

/// Descriptor for `PoseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List poseRequestDescriptor = $convert.base64Decode(
    'CgtQb3NlUmVxdWVzdBIdCgppbWFnZV9kYXRhGAEgASgMUglpbWFnZURhdGESKgoRbmV3X3NrZW'
    'xldG9uX2RhdGEYAiABKAxSD25ld1NrZWxldG9uRGF0YRIbCgludW1fc3RlcHMYAyABKAVSCG51'
    'bVN0ZXBzEjcKF2NvbnRyb2xuZXRfY29uZGl0aW9uaW5nGAQgASgCUhZjb250cm9sbmV0Q29uZG'
    'l0aW9uaW5nEhoKCHN0cmVuZ3RoGAUgASgCUghzdHJlbmd0aA==');

@$core.Deprecated('Use poseResponseDescriptor instead')
const PoseResponse$json = {
  '1': 'PoseResponse',
  '2': [
    {
      '1': 'processed_image_data',
      '3': 1,
      '4': 1,
      '5': 12,
      '10': 'processedImageData'
    },
  ],
};

/// Descriptor for `PoseResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List poseResponseDescriptor = $convert.base64Decode(
    'CgxQb3NlUmVzcG9uc2USMAoUcHJvY2Vzc2VkX2ltYWdlX2RhdGEYASABKAxSEnByb2Nlc3NlZE'
    'ltYWdlRGF0YQ==');
