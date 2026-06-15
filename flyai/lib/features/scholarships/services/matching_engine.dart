import 'package:flyai/features/profile/models/profile_model.dart';
import 'package:flyai/features/scholarships/models/scholarship_model.dart';

class MatchingEngine {
  MatchingEngine._();

  /// Calculate compatibility score 0–100 between student profile and scholarship
  static int calculate(ProfileModel profile, ScholarshipModel scholarship) {
    int score = 0;
    int maxScore = 0;

    // ── Education Level (25 pts) ───────────────────────────────────────
    maxScore += 25;
    if (_educationMatches(profile.educationLevel, scholarship.degreeLevel)) {
      score += 25;
    }

    // ── Field of Study (20 pts) ────────────────────────────────────────
    maxScore += 20;
    if (scholarship.fields.isEmpty) {
      score += 20; // Open to all fields
    } else {
      final profileField = profile.fieldOfStudy.toLowerCase();
      final targetFields =
          profile.targetFields.map((f) => f.toLowerCase()).toList();
      for (final field in scholarship.fields) {
        final f = field.toLowerCase();
        if (profileField.contains(f) ||
            f.contains(profileField) ||
            targetFields.any((t) => t.contains(f) || f.contains(t))) {
          score += 20;
          break;
        }
      }
    }

    // ── Target Country (20 pts) ────────────────────────────────────────
    maxScore += 20;
    final scholarshipCountry = scholarship.country.toLowerCase();
    final targetCountries =
        profile.targetCountries.map((c) => c.toLowerCase()).toList();
    if (targetCountries.isEmpty ||
        targetCountries.any((c) => c.contains(scholarshipCountry) ||
            scholarshipCountry.contains(c))) {
      score += 20;
    }

    // ── Nationality Eligibility (15 pts) ──────────────────────────────
    maxScore += 15;
    final eligibility = scholarship.eligibility;
    if (eligibility.isEmpty) {
      score += 15; // Open to all
    } else {
      final nationalities =
          (eligibility['nationalities'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
              [];
      final continent =
          (eligibility['continent'] as String?)?.toLowerCase() ?? '';
      final profileNat = profile.nationality.toLowerCase();
      if (nationalities.isEmpty ||
          nationalities.any((n) => n.contains(profileNat) || profileNat.contains(n)) ||
          (continent.isNotEmpty && _isAfrican(profileNat) && continent.contains('africa'))) {
        score += 15;
      }
    }

    // ── Language Requirements (10 pts) ────────────────────────────────
    maxScore += 10;
    final langReqs = scholarship.languageRequirements;
    if (langReqs.isEmpty) {
      score += 10;
    } else {
      bool langOk = true;
      if (langReqs.containsKey('english')) {
        final required = (langReqs['english'] as String?)?.toLowerCase() ?? '';
        final userLevel = profile.englishLevel.toLowerCase();
        if (!_languageLevelSufficient(userLevel, required)) langOk = false;
      }
      if (langReqs.containsKey('french')) {
        final required = (langReqs['french'] as String?)?.toLowerCase() ?? '';
        final userLevel = profile.frenchLevel.toLowerCase();
        if (!_languageLevelSufficient(userLevel, required)) langOk = false;
      }
      if (langOk) score += 10;
    }

    // ── GPA Bonus (10 pts) ────────────────────────────────────────────
    maxScore += 10;
    final minGpa = (eligibility['min_gpa'] as num?)?.toDouble();
    if (minGpa == null || profile.gpa >= minGpa) {
      score += 10;
    }

    if (maxScore == 0) return 0;
    return ((score / maxScore) * 100).clamp(0, 100).round();
  }

  static bool _educationMatches(String profileLevel, String scholarshipLevel) {
    final p = profileLevel.toLowerCase();
    final s = scholarshipLevel.toLowerCase();
    if (s.isEmpty || s == 'all') return true;
    if (p.contains('bachelor') && (s.contains('bachelor') || s.contains('undergraduate'))) return true;
    if (p.contains('master') && (s.contains('master') || s.contains('postgraduate'))) return true;
    if (p.contains('phd') || p.contains('doctorate')) {
      if (s.contains('phd') || s.contains('doctoral')) return true;
    }
    return p.contains(s) || s.contains(p);
  }

  static bool _languageLevelSufficient(String userLevel, String requiredLevel) {
    const levels = ['beginner', 'elementary', 'intermediate', 'upper-intermediate', 'advanced', 'proficient', 'native'];
    final userIdx = levels.indexWhere((l) => userLevel.contains(l));
    final reqIdx = levels.indexWhere((l) => requiredLevel.contains(l));
    if (reqIdx < 0) return true; // Unknown requirement
    if (userIdx < 0) return false; // Unknown user level
    return userIdx >= reqIdx;
  }

  static bool _isAfrican(String nationality) {
    const africanCountries = [
      'nigeria', 'ghana', 'kenya', 'ethiopia', 'south africa', 'egypt',
      'morocco', 'senegal', 'cameroon', 'ivory coast', 'tanzania',
      'uganda', 'rwanda', 'mali', 'guinea', 'togo', 'benin',
      'congo', 'angola', 'mozambique', 'zambia', 'zimbabwe',
      'madagascar', 'mauritius', 'algeria', 'tunisia', 'libya',
      'sudan', 'somalia', 'niger', 'chad', 'sierra leone', 'liberia',
    ];
    return africanCountries.any((c) => nationality.contains(c));
  }
}
