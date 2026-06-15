import 'package:equatable/equatable.dart';

class ScholarshipModel extends Equatable {
  final String id;
  final String title;
  final String provider;
  final String university;
  final String country;
  final String description;
  final String fundingType;
  final String degreeLevel;
  final List<String> fields;
  final Map<String, dynamic> eligibility;
  final List<String> requirements;
  final Map<String, dynamic> languageRequirements;
  final DateTime? deadline;
  final String? applicationUrl;
  final String? imageUrl;
  final String? source;
  final bool active;
  final DateTime? createdAt;
  final int compatibilityScore; // 0-100, computed on client

  const ScholarshipModel({
    required this.id,
    required this.title,
    required this.provider,
    required this.university,
    required this.country,
    required this.description,
    required this.fundingType,
    required this.degreeLevel,
    required this.fields,
    required this.eligibility,
    required this.requirements,
    required this.languageRequirements,
    this.deadline,
    this.applicationUrl,
    this.imageUrl,
    this.source,
    this.active = true,
    this.createdAt,
    this.compatibilityScore = 0,
  });

  factory ScholarshipModel.fromJson(Map<String, dynamic> json) {
    return ScholarshipModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      university: json['university'] as String? ?? '',
      country: json['country'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fundingType: json['funding_type'] as String? ?? 'Unknown',
      degreeLevel: json['degree_level'] as String? ?? '',
      fields: _parseStringList(json['fields']),
      eligibility: (json['eligibility'] as Map<String, dynamic>?) ?? {},
      requirements: _parseStringList(json['requirements']),
      languageRequirements:
          (json['language_requirements'] as Map<String, dynamic>?) ?? {},
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      applicationUrl: json['application_url'] as String?,
      imageUrl: json['image_url'] as String?,
      source: json['source'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      compatibilityScore: json['compatibility_score'] as int? ?? 0,
    );
  }

  ScholarshipModel copyWith({int? compatibilityScore}) {
    return ScholarshipModel(
      id: id,
      title: title,
      provider: provider,
      university: university,
      country: country,
      description: description,
      fundingType: fundingType,
      degreeLevel: degreeLevel,
      fields: fields,
      eligibility: eligibility,
      requirements: requirements,
      languageRequirements: languageRequirements,
      deadline: deadline,
      applicationUrl: applicationUrl,
      imageUrl: imageUrl,
      source: source,
      active: active,
      createdAt: createdAt,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
    );
  }

  bool get isDeadlineSoon {
    if (deadline == null) return false;
    final diff = deadline!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 30;
  }

  bool get isExpired {
    if (deadline == null) return false;
    return deadline!.isBefore(DateTime.now());
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  @override
  List<Object?> get props => [id, compatibilityScore];
}
