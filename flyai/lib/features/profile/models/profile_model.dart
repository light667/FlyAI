import 'package:equatable/equatable.dart';

class ProfileModel extends Equatable {
  final String id;
  final String firebaseUid;
  final String fullName;
  final String country;
  final String nationality;
  final DateTime? birthDate;
  final String educationLevel;
  final String fieldOfStudy;
  final String university;
  final double gpa;
  final String englishLevel;
  final String frenchLevel;
  final List<String> targetCountries;
  final List<String> targetFields;
  final String academicGoals;
  final String? cvUrl;
  final String? photoUrl;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.firebaseUid,
    required this.fullName,
    required this.country,
    required this.nationality,
    this.birthDate,
    required this.educationLevel,
    required this.fieldOfStudy,
    required this.university,
    required this.gpa,
    required this.englishLevel,
    required this.frenchLevel,
    required this.targetCountries,
    required this.targetFields,
    required this.academicGoals,
    this.cvUrl,
    this.photoUrl,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      firebaseUid: json['firebase_uid'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      country: json['country'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      educationLevel: json['education_level'] as String? ?? '',
      fieldOfStudy: json['field_of_study'] as String? ?? '',
      university: json['university'] as String? ?? '',
      gpa: (json['gpa'] as num?)?.toDouble() ?? 0.0,
      englishLevel: json['english_level'] as String? ?? '',
      frenchLevel: json['french_level'] as String? ?? '',
      targetCountries: _parseList(json['target_countries']),
      targetFields: _parseList(json['target_fields']),
      academicGoals: json['academic_goals'] as String? ?? '',
      cvUrl: json['cv_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'firebase_uid': firebaseUid,
        'full_name': fullName,
        'country': country,
        'nationality': nationality,
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'education_level': educationLevel,
        'field_of_study': fieldOfStudy,
        'university': university,
        'gpa': gpa,
        'english_level': englishLevel,
        'french_level': frenchLevel,
        'target_countries': targetCountries,
        'target_fields': targetFields,
        'academic_goals': academicGoals,
        'cv_url': cvUrl,
        'photo_url': photoUrl,
      };

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  ProfileModel copyWith({
    String? fullName,
    String? country,
    String? nationality,
    DateTime? birthDate,
    String? educationLevel,
    String? fieldOfStudy,
    String? university,
    double? gpa,
    String? englishLevel,
    String? frenchLevel,
    List<String>? targetCountries,
    List<String>? targetFields,
    String? academicGoals,
    String? cvUrl,
    String? photoUrl,
  }) {
    return ProfileModel(
      id: id,
      firebaseUid: firebaseUid,
      fullName: fullName ?? this.fullName,
      country: country ?? this.country,
      nationality: nationality ?? this.nationality,
      birthDate: birthDate ?? this.birthDate,
      educationLevel: educationLevel ?? this.educationLevel,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      university: university ?? this.university,
      gpa: gpa ?? this.gpa,
      englishLevel: englishLevel ?? this.englishLevel,
      frenchLevel: frenchLevel ?? this.frenchLevel,
      targetCountries: targetCountries ?? this.targetCountries,
      targetFields: targetFields ?? this.targetFields,
      academicGoals: academicGoals ?? this.academicGoals,
      cvUrl: cvUrl ?? this.cvUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, firebaseUid];
}
