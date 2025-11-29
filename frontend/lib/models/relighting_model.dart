import 'dart:convert';

class LightGeometry {
  final String type;
  final List<List<double>>? coordinates;
  final List<double>? center;
  final double? radius;

  LightGeometry({
    required this.type,
    this.coordinates,
    this.center,
    this.radius,
  });

  Map<dynamic, dynamic> toJson() {
    final map = {};
    map['type'] = type;
    if (coordinates != null) map['coordinates'] = coordinates;
    if (center != null) map['center'] = center;
    if (radius != null) map['radius'] = radius;
    return map;
  }
}

class LightProperties {
  final int? temperature;
  final String? color;

  LightProperties({this.temperature, this.color});

  Map<dynamic, dynamic> toJson() {
    final map = {};
    if (temperature != null) map['temperature'] = temperature;
    if (color != null) map['color'] = color;
    return map;
  }
}

class Light {
  final LightGeometry geometry;
  final LightProperties properties;

  Light({required this.geometry, required this.properties});

  Map<dynamic, dynamic> toJson() {
    final map = {};
    map['geometry'] = geometry.toJson();
    map['properties'] = properties.toJson();
    return map;
  }
}

class LightsRequest {
  final List<Light> lights;

  LightsRequest({required this.lights});

  Map<dynamic, dynamic> toJson() {
    final map = {};
    map['lights'] = lights.map((l) => l.toJson()).toList();
    return map;
  }

  String toRawJson() => json.encode(toJson());
}
