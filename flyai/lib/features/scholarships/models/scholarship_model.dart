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
    final title = json['title'] as String? ?? json['titre'] as String? ?? '';
    final provider = json['provider'] as String? ?? json['source'] as String? ?? '';
    final university = json['university'] as String? ?? json['universite'] as String? ?? '';
    
    // In bourses, pays_destination is a list of strings
    final countryRaw = json['country'];
    final String country = countryRaw is String
        ? countryRaw
        : _parseStringList(json['pays_destination'] ?? json['pays_destination_raw']).join(', ');

    final description = json['description'] as String? ?? '';
    final fundingType = json['funding_type'] as String? ?? json['financement'] as String? ?? 'Unknown';
    
    // In bourses, niveau_etude is a list of strings
    final degreeLevelRaw = json['degree_level'];
    final String degreeLevel = degreeLevelRaw is String
        ? degreeLevelRaw
        : _parseStringList(json['niveau_etude'] ?? json['niveau_raw']).join(', ');

    final fields = _parseStringList(json['fields'] ?? json['domaines']);

    // Build structured eligibility for matching engine
    Map<String, dynamic> eligibility = {};
    if (json['eligibility'] is Map) {
      eligibility = Map<String, dynamic>.from(json['eligibility'] as Map);
    } else {
      eligibility = {
        'nationalities': _parseStringList(json['nationalites_eligibles'] ?? json['nationalite_raw']),
        'continent': (json['africains_eligibles'] as bool? ?? false) ? 'africa' : '',
        'min_gpa': 0.0,
      };
    }

    final requirements = _parseStringList(json['requirements'] ?? json['avantages'] ?? json['criteres']);

    // Build structured language requirements for matching engine
    Map<String, dynamic> languageRequirements = {};
    if (json['language_requirements'] is Map) {
      languageRequirements = Map<String, dynamic>.from(json['language_requirements'] as Map);
    } else if (json['langues_requises'] != null) {
      final langs = _parseStringList(json['langues_requises']);
      for (final l in langs) {
        final low = l.toLowerCase();
        if (low.contains('anglais') || low.contains('english')) {
          languageRequirements['english'] = 'intermediate';
        }
        if (low.contains('français') || low.contains('french') || low.contains('francais')) {
          languageRequirements['french'] = 'intermediate';
        }
      }
    }

    return ScholarshipModel(
      id: json['id'] as String? ?? '',
      title: title,
      provider: provider,
      university: university,
      country: country.isNotEmpty ? country : 'International',
      description: description,
      fundingType: fundingType,
      degreeLevel: degreeLevel.isNotEmpty ? degreeLevel : 'Undergraduate/Postgraduate',
      fields: fields,
      eligibility: eligibility,
      requirements: requirements,
      languageRequirements: languageRequirements,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      applicationUrl: json['application_url'] as String? ?? json['lien_candidature'] as String?,
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
