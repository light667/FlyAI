/// Interface abstraite pour toutes les chaînes de l'application.
/// Implémenter [AppStringsFr] et [AppStringsEn].
abstract class AppStringsBase {
  // App
  String get appName;
  String get appTagline;

  // Onboarding
  String get onboarding1Title;
  String get onboarding1Desc;
  String get onboarding2Title;
  String get onboarding2Desc;
  String get onboarding3Title;
  String get onboarding3Desc;
  String get skip;
  String get next;
  String get getStarted;

  // Auth
  String get welcomeBack;
  String get welcomeBackSub;
  String get createAccount;
  String get createAccountSub;
  String get signIn;
  String get signUp;
  String get signOut;
  String get continueWithGoogle;
  String get continueWithApple;
  String get alreadyHaveAccount;
  String get dontHaveAccount;
  String get emailLabel;
  String get emailHint;
  String get sendMagicLink;
  String get emailSentTitle;
  String get emailSentDesc;
  String get checkSpam;
  String get resendLink;
  String get backToSignIn;
  String get orContinueWith;
  String get chooseLanguage;
  String get fullNameLabel;
  String get passwordLabel;
  String get confirmPasswordLabel;
  String get passwordTooShort;
  String get passwordsDoNotMatch;
  String get forgotPassword;

  // Email link auth
  String get verifyingLink;
  String get linkExpired;
  String get enterEmailAgain;
  String get confirm;

  // Profile
  String get setupProfile;
  String get profileSetupDesc;
  String get stepOf;
  String get country;
  String get nationality;
  String get dateOfBirth;
  String get educationLevel;
  String get university;
  String get fieldOfStudy;
  String get academicScore;
  String get academicScoreHint;
  String get convertedGpa;
  String get englishLevel;
  String get frenchLevel;
  String get targetCountries;
  String get targetFields;
  String get academicGoals;
  String get academicGoalsHint;
  String get uploadCV;
  String get uploadPhoto;
  String get selectCvFile;
  String get cvSupportedFormats;
  String get changePhoto;
  String get profilePhotoAndCv;
  String get profilePhotoAndCvDesc;
  String get personalInfo;
  String get personalInfoDesc;
  String get academicProfile;
  String get academicProfileDesc;
  String get preferencesAndLanguages;
  String get preferencesAndLanguagesDesc;
  String get targetStudyCountries;
  String get targetStudyFields;
  String get back;
  String get finish;
  String get saving;
  String get otherLanguages;
  String get addLanguage;
  String get languageName;
  String get proficiencyLevel;
  String get selectLanguage;
  String get selectLevel;
  String get remove;

  // Navigation
  String get discover;
  String get dashboard;
  String get aiAssistant;
  String get applications;
  String get profile;

  // Dashboard
  String get totalMatches;
  String get savedScholarships;
  String get activeApplications;
  String get avgCompatibility;
  String get myScholarships;
  String get priorityScholarships;
  String get recentActivity;

  // Swipe
  String get noMoreScholarships;
  String get noMoreDesc;
  String get compatibility;

  // Scholarship
  String get deadline;
  String get fundingType;
  String get degreeLevel;
  String get startApplication;
  String get viewDetails;

  // AI Assistant
  String get flyAssistant;
  String get askAnything;
  String get assistantWelcome;

  // Application
  String get applicationProgress;
  String get checklist;

  // Settings
  String get settings;
  String get account;
  String get editProfile;
  String get editProfileSub;
  String get notifications;
  String get pushNotifications;
  String get emailUpdates;
  String get privacyAndData;
  String get anonymousAnalytics;
  String get privacyPolicy;
  String get termsOfService;
  String get logOut;
  String get appLanguage;
  String get french;
  String get english;
  String get privacyPolicyContent;
  String get termsOfServiceContent;
  String get close;

  // Errors
  String get genericError;
  String get noInternet;
  String get invalidEmail;
  String get fieldRequired;
  String get uploadPhotoFailed;
  String get uploadCvFailed;
  String get profileSavedWithoutFiles;
}
