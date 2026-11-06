import 'package:flutter/foundation.dart';

import 'enums.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.siteIds,
    this.phone,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final List<String> siteIds;
  final String? phone;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      role: UserRole.fromWire(map['role'] as String?),
      siteIds: (map['siteIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      phone: map['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'email': email,
    'role': role.wireName,
    'siteIds': siteIds,
    if (phone != null) 'phone': phone,
  };
}

@immutable
class Site {
  const Site({
    required this.id,
    required this.name,
    required this.village,
    required this.regency,
    required this.tempekCount,
    required this.gateCount,
    required this.dataState,
  });

  final String id;
  final String name;
  final String village;
  final String regency;
  final int tempekCount;
  final int gateCount;
  final DataState dataState;

  String get locationLabel => '$village, $regency';
}

@immutable
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.siteId,
    required this.kind,
    required this.mode,
    required this.dataState,
    required this.lastSeen,
    this.positionPercent,
    this.batteryPercent,
    this.rssi,
    this.firmware,
    this.motorCurrentAmp,
    this.upperLimit,
    this.lowerLimit,
  });

  final String id;
  final String name;
  final String siteId;
  final DeviceKind kind;
  final GateMode mode;
  final DataState dataState;
  final DateTime lastSeen;
  final double? positionPercent;
  final double? batteryPercent;
  final int? rssi;
  final String? firmware;
  final double? motorCurrentAmp;
  final bool? upperLimit;
  final bool? lowerLimit;

  bool get isGate => kind == DeviceKind.gate;
}

@immutable
class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.deviceId,
    required this.upstreamCm,
    required this.downstreamCm,
    required this.flowLiterPerSecond,
    required this.recordedAt,
    required this.dataState,
    required this.quality,
  });

  final String deviceId;
  final double upstreamCm;
  final double downstreamCm;
  final double flowLiterPerSecond;
  final DateTime recordedAt;
  final DataState dataState;
  final String quality;
}

@immutable
class WaterRule {
  const WaterRule({
    required this.id,
    required this.siteId,
    required this.tempek,
    required this.version,
    required this.status,
    required this.allocationShare,
    required this.scheduleLabel,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.parumanReference,
    required this.updatedAt,
  });

  final String id;
  final String siteId;
  final String tempek;
  final int version;
  final RuleStatus status;
  final double allocationShare;
  final String scheduleLabel;
  final DateTime effectiveFrom;
  final DateTime effectiveTo;
  final String parumanReference;
  final DateTime updatedAt;

  bool get isImmutable => status != RuleStatus.draft;
}

@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.siteId,
    required this.tempek,
    required this.gateId,
    required this.ruleId,
    required this.ruleVersion,
    required this.recordedAt,
    required this.volumeCubicMeter,
    required this.actor,
    required this.source,
    required this.prevHash,
    required this.hash,
    this.correctionOf,
  });

  final String id;
  final String siteId;
  final String tempek;
  final String gateId;
  final String ruleId;
  final int ruleVersion;
  final DateTime recordedAt;
  final double volumeCubicMeter;
  final String actor;
  final String source;
  final String prevHash;
  final String hash;
  final String? correctionOf;

  Map<String, dynamic> toHashPayload() => <String, dynamic>{
    'id': id,
    'siteId': siteId,
    'tempek': tempek,
    'gateId': gateId,
    'ruleId': ruleId,
    'ruleVersion': ruleVersion,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'volumeCubicMeter': volumeCubicMeter.toStringAsFixed(3),
    'actor': actor,
    'source': source,
    if (correctionOf != null) 'correctionOf': correctionOf,
  };
}

@immutable
class Alert {
  const Alert({
    required this.id,
    required this.siteId,
    required this.deviceId,
    required this.severity,
    required this.title,
    required this.evidence,
    required this.suggestedAction,
    required this.raisedAt,
    required this.acknowledged,
    this.acknowledgedBy,
    this.acknowledgedAt,
  });

  final String id;
  final String siteId;
  final String deviceId;
  final AlertSeverity severity;
  final String title;
  final String evidence;
  final String suggestedAction;
  final DateTime raisedAt;
  final bool acknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;

  Alert copyWith({
    bool? acknowledged,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
  }) {
    return Alert(
      id: id,
      siteId: siteId,
      deviceId: deviceId,
      severity: severity,
      title: title,
      evidence: evidence,
      suggestedAction: suggestedAction,
      raisedAt: raisedAt,
      acknowledged: acknowledged ?? this.acknowledged,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }
}

@immutable
class GateCommand {
  const GateCommand({
    required this.id,
    required this.gateId,
    required this.siteId,
    required this.action,
    required this.targetPositionPercent,
    required this.status,
    required this.createdAt,
    required this.actorUid,
    required this.ruleId,
    required this.reason,
    this.expiresAt,
    this.updatedAt,
    this.failureReason,
  });

  final String id;
  final String gateId;
  final String siteId;
  final String action;
  final double targetPositionPercent;
  final CommandStatus status;
  final DateTime createdAt;
  final String actorUid;
  final String ruleId;
  final String reason;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
  final String? failureReason;

  GateCommand copyWith({
    CommandStatus? status,
    DateTime? updatedAt,
    String? failureReason,
  }) {
    return GateCommand(
      id: id,
      gateId: gateId,
      siteId: siteId,
      action: action,
      targetPositionPercent: targetPositionPercent,
      status: status ?? this.status,
      createdAt: createdAt,
      actorUid: actorUid,
      ruleId: ruleId,
      reason: reason,
      expiresAt: expiresAt,
      updatedAt: updatedAt ?? this.updatedAt,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.createdAt,
    this.sources = const <String>[],
    this.isFallback = false,
  });

  final String id;
  final bool isUser;
  final String text;
  final DateTime createdAt;
  final List<String> sources;
  final bool isFallback;
}

@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.site,
    required this.onlineDevices,
    required this.totalDevices,
    required this.averageBatteryPercent,
    required this.telemetry,
    required this.activeAlerts,
    required this.lastGateEvents,
    required this.dataState,
  });

  final Site site;
  final int onlineDevices;
  final int totalDevices;
  final double averageBatteryPercent;
  final TelemetrySnapshot telemetry;
  final List<Alert> activeAlerts;
  final List<String> lastGateEvents;
  final DataState dataState;
}
