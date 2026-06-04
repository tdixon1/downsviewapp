class MemberProfile {
  const MemberProfile({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.preferredContactMethod,
    this.ministryInterest,
    this.householdNotes,
    this.birthday,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? preferredContactMethod;
  final String? ministryInterest;
  final String? householdNotes;
  final String? birthday;
  final String? avatarUrl;

  factory MemberProfile.fromMap(Map<String, dynamic> map) => MemberProfile(
        id: map['id'] as String,
        email: map['email'] as String?,
        fullName: map['full_name'] as String?,
        phone: map['phone'] as String?,
        preferredContactMethod: map['preferred_contact_method'] as String?,
        ministryInterest: map['ministry_interest'] as String?,
        householdNotes: map['household_notes'] as String?,
        birthday: map['birthday'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );
}

class FollowUpResponse {
  const FollowUpResponse({
    required this.id,
    required this.responseData,
    required this.followUpStatus,
    required this.createdAt,
    this.userId,
    this.requesterName,
    this.requesterEmail,
    this.followUpNotes,
    this.assignedToName,
    this.interestType,
    this.contactedByName,
    this.contactedAt,
    this.followUpNextActionAt,
  });

  final String id;
  final String? userId;
  final String? requesterName;
  final String? requesterEmail;
  final String responseData;
  final String followUpStatus;
  final String? followUpNotes;
  final String? assignedToName;
  final String? interestType;
  final String? contactedByName;
  final DateTime? contactedAt;
  final DateTime? followUpNextActionAt;
  final DateTime createdAt;

  factory FollowUpResponse.fromMap(Map<String, dynamic> map) => FollowUpResponse(
        id: map['id'] as String,
        userId: map['user_id'] as String?,
        requesterName: map['requester_name'] as String?,
        requesterEmail: map['requester_email'] as String?,
        responseData: (map['response_data'] ?? '') as String,
        followUpStatus: (map['follow_up_status'] ?? 'new') as String,
        followUpNotes: map['follow_up_notes'] as String?,
        assignedToName: map['assigned_to_name'] as String?,
        interestType: map['interest_type'] as String?,
        contactedByName: map['contacted_by_name'] as String?,
        contactedAt: DateTime.tryParse((map['contacted_at'] ?? '') as String),
        followUpNextActionAt:
            DateTime.tryParse((map['follow_up_next_action_at'] ?? '') as String),
        createdAt: DateTime.tryParse((map['created_at'] ?? '') as String) ??
            DateTime.now(),
      );
}

class AttendanceLog {
  const AttendanceLog({
    required this.id,
    required this.timestamp,
    this.userId,
    this.userName,
    this.userEmail,
    this.deviceId,
  });

  final String id;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? deviceId;
  final DateTime timestamp;

  factory AttendanceLog.fromMap(Map<String, dynamic> map) => AttendanceLog(
        id: map['id'] as String,
        userId: map['user_id'] as String?,
        userName: map['user_name'] as String?,
        userEmail: map['user_email'] as String?,
        deviceId: map['device_id'] as String?,
        timestamp: DateTime.tryParse((map['timestamp'] ?? '') as String) ??
            DateTime.now(),
      );
}
