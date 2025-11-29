// This is a generated file - do not edit.
//
// Generated from relighting.proto.

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

import 'relighting.pb.dart' as $0;

export 'relighting.pb.dart';

@$pb.GrpcServiceName('relighting.RelightingService')
class RelightingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  RelightingServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.RelightResponse> relight(
    $0.RelightRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$relight, request, options: options);
  }

  // method descriptors

  static final _$relight =
      $grpc.ClientMethod<$0.RelightRequest, $0.RelightResponse>(
          '/relighting.RelightingService/Relight',
          ($0.RelightRequest value) => value.writeToBuffer(),
          $0.RelightResponse.fromBuffer);
}

@$pb.GrpcServiceName('relighting.RelightingService')
abstract class RelightingServiceBase extends $grpc.Service {
  $core.String get $name => 'relighting.RelightingService';

  RelightingServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RelightRequest, $0.RelightResponse>(
        'Relight',
        relight_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RelightRequest.fromBuffer(value),
        ($0.RelightResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.RelightResponse> relight_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RelightRequest> $request) async {
    return relight($call, await $request);
  }

  $async.Future<$0.RelightResponse> relight(
      $grpc.ServiceCall call, $0.RelightRequest request);
}
