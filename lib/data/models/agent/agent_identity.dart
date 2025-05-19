// lib/data/models/agent/agent_identity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات هوية الوكيل في Firestore
class AgentIdentity {
  final String agentCode;
  final String displayName;
  final String? deviceId;
  final bool deviceBindingRequired;
  final bool needsAdminApprovalForNewDevice;
  final DateTime? lastLoginAt;
  final String? lastLoginDeviceId;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  AgentIdentity({
    required this.agentCode,
    required this.displayName,
    this.deviceId,
    this.deviceBindingRequired = true,
    this.needsAdminApprovalForNewDevice = false,
    this.lastLoginAt,
    this.lastLoginDeviceId,
    this.isActive = true,
    this.metadata,
  });

  /// إنشاء نموذج من بيانات Firestore
  factory AgentIdentity.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    return AgentIdentity(
      agentCode: doc.id,
      displayName: data['displayName'] as String? ?? doc.id,
      deviceId: data['deviceId'] as String?,
      deviceBindingRequired: data['deviceBindingRequired'] as bool? ?? true,
      needsAdminApprovalForNewDevice: data['needsAdminApprovalForNewDevice'] as bool? ?? false,
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      lastLoginDeviceId: data['lastLoginDeviceId'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// تحويل النموذج إلى بيانات Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'deviceId': deviceId,
      'deviceBindingRequired': deviceBindingRequired,
      'needsAdminApprovalForNewDevice': needsAdminApprovalForNewDevice,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'lastLoginDeviceId': lastLoginDeviceId,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// إنشاء نسخة معدلة من النموذج
  AgentIdentity copyWith({
    String? displayName,
    String? deviceId,
    bool? deviceBindingRequired,
    bool? needsAdminApprovalForNewDevice,
    DateTime? lastLoginAt,
    String? lastLoginDeviceId,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return AgentIdentity(
      agentCode: this.agentCode,
      displayName: displayName ?? this.displayName,
      deviceId: deviceId ?? this.deviceId,
      deviceBindingRequired: deviceBindingRequired ?? this.deviceBindingRequired,
      needsAdminApprovalForNewDevice: needsAdminApprovalForNewDevice ?? this.needsAdminApprovalForNewDevice,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginDeviceId: lastLoginDeviceId ?? this.lastLoginDeviceId,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }
}
