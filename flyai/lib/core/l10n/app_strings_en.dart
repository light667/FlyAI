import 'app_strings_base.dart';

/// All app strings in English (secondary language).
class AppStringsEn implements AppStringsBase {
  const AppStringsEn();

  // App
  @override String get appName => 'Fly AI';
  @override String get appTagline => 'Swipe. Match. Apply. Fly.';

  // Onboarding
  @override String get onboarding1Title => 'Find Your Next\nOpportunity';
  @override String get onboarding1Desc => 'Discover scholarships tailored to your profile and ambitions from around the world.';
  @override String get onboarding2Title => 'AI Finds Your\nBest Matches';
  @override String get onboarding2Desc => 'Swipe through opportunities and receive personalized recommendations powered by AI.';
  @override String get onboarding3Title => 'Build Your Future\nWith Confidence';
  @override String get onboarding3Desc => 'Get AI assistance throughout your scholarship application journey.';
  @override String get skip => 'Skip';
  @override String get next => 'Next';
  @override String get getStarted => 'Get Started';

  // Auth
  @override String get welcomeBack => 'Welcome back 👋';
  @override String get welcomeBackSub => 'Sign in to continue your journey';
  @override String get createAccount => 'Create Account ✨';
  @override String get createAccountSub => 'Start your scholarship journey today';
  @override String get signIn => 'Sign In';
  @override String get signUp => 'Sign Up';
  @override String get signOut => 'Sign Out';
  @override String get continueWithGoogle => 'Continue with Google';
  @override String get continueWithApple => 'Continue with Apple';
  @override String get alreadyHaveAccount => 'Already have an account? ';
  @override String get dontHaveAccount => "Don't have an account? ";
  @override String get emailLabel => 'Email address';
  @override String get emailHint => 'you@example.com';
  @override String get sendMagicLink => 'Send sign-in link';
  @override String get emailSentTitle => 'Email Sent! ✉️';
  @override String get emailSentDesc => 'Check your inbox and click the link to sign in.';
  @override String get checkSpam => 'Also check your spam folder if you don\'t receive anything.';
  @override String get resendLink => 'Resend link';
  @override String get backToSignIn => 'Back to Sign In';
  @override String get orContinueWith => 'or continue with';
  @override String get chooseLanguage => 'Choose language';
  @override String get fullNameLabel => 'Full name';
  @override String get passwordLabel => 'Password';
  @override String get confirmPasswordLabel => 'Confirm password';
  @override String get passwordTooShort => 'Password must be at least 6 characters.';
  @override String get passwordsDoNotMatch => 'Passwords do not match.';
  @override String get forgotPassword => 'Forgot password?';

  // Email link auth
  @override String get verifyingLink => 'Verifying link…';
  @override String get linkExpired => 'Link expired or invalid';
  @override String get enterEmailAgain => 'Enter your email address to continue';
  @override String get confirm => 'Confirm';

  // Profile
  @override String get setupProfile => 'Set Up Profile 🎓';
  @override String get profileSetupDesc => 'Help us find the best scholarships for you.';
  @override String get stepOf => 'Step';
  @override String get country => 'Country';
  @override String get nationality => 'Nationality';
  @override String get dateOfBirth => 'Date of Birth';
  @override String get educationLevel => 'Education Level';
  @override String get university => 'University / School';
  @override String get fieldOfStudy => 'Field of Study';
  @override String get academicScore => 'Academic Score (out of 20)';
  @override String get academicScoreHint => 'e.g. 14.5';
  @override String get convertedGpa => 'Converted GPA';
  @override String get englishLevel => 'English Level';
  @override String get frenchLevel => 'French Level';
  @override String get targetCountries => 'Target Countries';
  @override String get targetFields => 'Target Fields';
  @override String get academicGoals => 'Academic / Career Goals';
  @override String get academicGoalsHint => 'Describe your future aspirations…';
  @override String get uploadCV => 'Upload CV';
  @override String get uploadPhoto => 'Upload Photo';
  @override String get selectCvFile => 'Select CV File';
  @override String get cvSupportedFormats => 'Supports PDF, DOC, DOCX up to 10MB';
  @override String get changePhoto => 'Change Photo';
  @override String get profilePhotoAndCv => 'Profile Photo & CV';
  @override String get profilePhotoAndCvDesc => 'Upload these to enable CV reviews and application checklists.';
  @override String get personalInfo => 'Tell us about yourself';
  @override String get personalInfoDesc => 'Help us verify your eligibility for regional academic opportunities.';
  @override String get academicProfile => 'Academic profile';
  @override String get academicProfileDesc => 'Provide your academic metrics to match with degree requirements.';
  @override String get preferencesAndLanguages => 'Preferences & Languages';
  @override String get preferencesAndLanguagesDesc => 'Tell us where you want to study and which languages you speak.';
  @override String get targetStudyCountries => 'Target Study Countries (Select multiple)';
  @override String get targetStudyFields => 'Target Study Fields (Select multiple)';
  @override String get back => 'Back';
  @override String get finish => 'Finish';
  @override String get saving => 'Saving…';
  @override String get otherLanguages => 'Other languages spoken';
  @override String get addLanguage => '+ Add a language';
  @override String get languageName => 'Language';
  @override String get proficiencyLevel => 'Proficiency level';
  @override String get selectLanguage => 'Select a language';
  @override String get selectLevel => 'Select level';
  @override String get remove => 'Remove';

  // Navigation
  @override String get discover => 'Discover';
  @override String get dashboard => 'Dashboard';
  @override String get aiAssistant => 'Fly Assistant';
  @override String get applications => 'Applications';
  @override String get profile => 'Profile';

  // Dashboard
  @override String get totalMatches => 'Total Matches';
  @override String get savedScholarships => 'Saved';
  @override String get activeApplications => 'Active';
  @override String get avgCompatibility => 'Avg. Match';
  @override String get myScholarships => 'My Scholarships';
  @override String get priorityScholarships => 'Priority';
  @override String get recentActivity => 'Recent Activity';

  // Swipe
  @override String get noMoreScholarships => 'No more scholarships!';
  @override String get noMoreDesc => 'Check back later for new opportunities.';
  @override String get compatibility => 'Match';

  // Scholarship
  @override String get deadline => 'Deadline';
  @override String get fundingType => 'Funding';
  @override String get degreeLevel => 'Degree';
  @override String get startApplication => 'Start Application';
  @override String get viewDetails => 'View Details';

  // AI Assistant
  @override String get flyAssistant => 'Fly Assistant';
  @override String get askAnything => 'Ask me anything…';
  @override String get assistantWelcome =>
      'Hi! I\'m Fly Assistant 🚀\n\nI can help you with:\n• CV Review\n• Motivation Letters\n• SOP Writing\n• Interview Prep\n• Scholarship Strategy\n\nWhat can I help you with today?';

  // Application
  @override String get applicationProgress => 'Application Progress';
  @override String get checklist => 'Checklist';

  // Settings
  @override String get settings => 'Settings ⚙️';
  @override String get account => 'Account';
  @override String get editProfile => 'Edit Profile Details';
  @override String get editProfileSub => 'Update academic targets and language levels';
  @override String get notifications => 'Notifications';
  @override String get pushNotifications => 'Push Notifications';
  @override String get emailUpdates => 'Email Updates';
  @override String get privacyAndData => 'Privacy & Data';
  @override String get anonymousAnalytics => 'Anonymous Usage Analytics';
  @override String get privacyPolicy => 'Privacy Policy';
  @override String get termsOfService => 'Terms of Service';
  @override String get logOut => 'Log Out Account';
  @override String get appLanguage => 'App language';
  @override String get french => 'Français';
  @override String get english => 'English';
  @override String get privacyPolicyContent =>
      'Your student profile information is saved securely on Supabase servers and used only to evaluate matching metrics with regional scholarships.';
  @override String get termsOfServiceContent =>
      'By using Fly AI, you consent to our automated scholarship eligibility and matching processes.';
  @override String get close => 'Close';

  // Errors
  @override String get genericError => 'Something went wrong. Please try again.';
  @override String get noInternet => 'No internet connection.';
  @override String get invalidEmail => 'Please enter a valid email address.';
  @override String get fieldRequired => 'This field is required.';
  @override String get uploadPhotoFailed => 'Photo upload failed. Profile saved without photo.';
  @override String get uploadCvFailed => 'CV upload failed. Profile saved without CV.';
  @override String get profileSavedWithoutFiles => 'Profile saved. Some files could not be uploaded.';
}
