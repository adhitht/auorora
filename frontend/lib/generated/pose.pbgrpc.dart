// This is a generated file - do not edit.
//
// Generated from pose.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'pose.pb.dart' as $0;

export 'pose.pb.dart';

@$pb.GrpcServiceName('pose.PoseChangingService')
class PoseChangingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PoseChangingServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.PoseResponse> changePose(
    $0.PoseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$changePose, request, options: options);
  }

  // method descriptors

  static final _$changePose =
      $grpc.ClientMethod<$0.PoseRequest, $0.PoseResponse>(
          '/pose.PoseChangingService/ChangePose',
          ($0.PoseRequest value) => value.writeToBuffer(),
          $0.PoseResponse.fromBuffer);
}

@$pb.GrpcServiceName('pose.PoseChangingService')
abstract class PoseChangingServiceBase extends $grpc.Service {
  $core.String get $name => 'pose.PoseChangingService';

  PoseChangingServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.PoseRequest, $0.PoseResponse>(
        'ChangePose',
        changePose_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PoseRequest.fromBuffer(value),
        ($0.PoseResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.PoseResponse> changePose_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PoseRequest> $request) async {
    return changePose($call, await $request);
  }

  $async.Future<$0.PoseResponse> changePose(
      $grpc.ServiceCall call, $0.PoseRequest request);
}
