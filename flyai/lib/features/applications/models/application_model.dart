import 'package:equatable/equatable.dart';
import '../../scholarships/models/scholarship_model.dart';

class ApplicationModel extends Equatable {
  final String id;
  final String firebaseUid;
  final String scholarshipId;
  final String status; // 'draft' | 'submitted' | 'accepted' | 'rejected'
  final int progress; // 0 to 100
  final Map<String, bool> checklist; // e.g. {'CV': true, 'Passport': false, ...}
  final ScholarshipModel? scholarship;
  final DateTime createdAt;

  const ApplicationModel({
    required this.id,
    required this.firebaseUid,
    required this.scholarshipId,
    required this.status,
    required this.progress,
    required this.checklist,
    this.scholarship,
    required this.createdAt,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final checklistRaw = json['checklist'];
    final Map<String, bool> parsedChecklist = {
      'CV': false,
      'Passport': false,
      'Degree Certificate': false,
      'Academic Transcript': false,
      'Recommendation Letter': false,
      'Motivation Letter': false,
    };
    if (checklistRaw is Map) {
      checklistRaw.forEach((k, v) {
        parsedChecklist[k.toString()] = v == true;
      });
    }

    final scholarshipRaw = json['bourses'] ?? json['scholarships'];
    final ScholarshipModel? fetchedScholarship = scholarshipRaw != null
        ? ScholarshipModel.fromJson(scholarshipRaw as Map<String, dynamic>)
        : null;

    return ApplicationModel(
      id: json['id'] as String? ?? '',
      firebaseUid: json['firebase_uid'] as String? ?? '',
      scholarshipId: json['scholarship_id'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      progress: json['progress'] as int? ?? 0,
      checklist: parsedChecklist,
      scholarship: fetchedScholarship,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'firebase_uid': firebaseUid,
        'scholarship_id': scholarshipId,
        'status': status,
        'progress': progress,
        'checklist': checklist,
      };

  ApplicationModel copyWith({
    String? status,
    int? progress,
    Map<String, bool>? checklist,
    ScholarshipModel? scholarship,
  }) {
    return ApplicationModel(
      id: id,
      firebaseUid: firebaseUid,
      scholarshipId: scholarshipId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      checklist: checklist ?? this.checklist,
      scholarship: scholarship ?? this.scholarship,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, firebaseUid, scholarshipId, status, progress, checklist, scholarship];
}
