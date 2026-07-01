import 'app_strings_base.dart';

/// Toutes les chaînes de l'application en Français (langue par défaut).
class AppStringsFr implements AppStringsBase {
  const AppStringsFr();

  // App
  @override String get appName => 'Fly AI';
  @override String get appTagline => 'Glisse. Matche. Postule. Envole-toi.';

  // Onboarding
  @override String get onboarding1Title => 'Trouve ta prochaine\nOpportunité';
  @override String get onboarding1Desc => 'Découvre des bourses adaptées à ton profil et tes ambitions, partout dans le monde.';
  @override String get onboarding2Title => "L'IA trouve tes\nMeilleures Opportunités";
  @override String get onboarding2Desc => 'Glisse à travers les opportunités et reçois des recommandations personnalisées grâce à l\'IA.';
  @override String get onboarding3Title => 'Construis ton Avenir\nAvec Confiance';
  @override String get onboarding3Desc => "Bénéficie de l'assistance IA tout au long de ton parcours de candidature aux bourses.";
  @override String get skip => 'Passer';
  @override String get next => 'Suivant';
  @override String get getStarted => 'Commencer';

  // Auth
  @override String get welcomeBack => 'Bon retour';
  @override String get welcomeBackSub => 'Connecte-toi pour continuer ton voyage';
  @override String get createAccount => 'Créer un compte';
  @override String get createAccountSub => 'Commence ton parcours vers les bourses aujourd\'hui';
  @override String get signIn => 'Se connecter';
  @override String get signUp => 'S\'inscrire';
  @override String get signOut => 'Se déconnecter';
  @override String get continueWithGoogle => 'Continuer avec Google';
  @override String get continueWithApple => 'Continuer avec Apple';
  @override String get alreadyHaveAccount => 'Déjà un compte ? ';
  @override String get dontHaveAccount => 'Pas encore de compte ? ';
  @override String get emailLabel => 'Adresse e-mail';
  @override String get emailHint => 'toi@exemple.com';
  @override String get sendMagicLink => 'Recevoir le lien de connexion';
  @override String get emailSentTitle => 'E-mail envoyé !';
  @override String get emailSentDesc => 'Vérifie ta boîte mail et clique sur le lien pour te connecter.';
  @override String get checkSpam => 'Vérifie aussi tes spams si tu ne reçois rien.';
  @override String get resendLink => 'Renvoyer le lien';
  @override String get backToSignIn => 'Retour à la connexion';
  @override String get orContinueWith => 'ou continuer avec';
  @override String get chooseLanguage => 'Choisir la langue';
  @override String get fullNameLabel => 'Nom complet';
  @override String get passwordLabel => 'Mot de passe';
  @override String get confirmPasswordLabel => 'Confirmer le mot de passe';
  @override String get passwordTooShort => 'Le mot de passe doit contenir au moins 6 caractères.';
  @override String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas.';
  @override String get forgotPassword => 'Mot de passe oublié ?';

  // Email link auth
  @override String get verifyingLink => 'Vérification du lien…';
  @override String get linkExpired => 'Lien expiré ou invalide';
  @override String get enterEmailAgain => 'Saisis ton adresse e-mail pour continuer';
  @override String get confirm => 'Confirmer';

  // Profile
  @override String get setupProfile => 'Configurer mon profil';
  @override String get profileSetupDesc => 'Aide-nous à trouver les meilleures bourses pour toi.';
  @override String get stepOf => 'Étape';
  @override String get country => 'Pays';
  @override String get nationality => 'Nationalité';
  @override String get dateOfBirth => 'Date de naissance';
  @override String get educationLevel => 'Niveau d\'études';
  @override String get university => 'Université / École';
  @override String get fieldOfStudy => 'Filière d\'études';
  @override String get academicScore => 'Note académique (sur 20)';
  @override String get academicScoreHint => 'ex. 14.5';
  @override String get convertedGpa => 'GPA converti';
  @override String get englishLevel => 'Niveau d\'anglais';
  @override String get frenchLevel => 'Niveau de français';
  @override String get targetCountries => 'Pays de destination';
  @override String get targetFields => 'Filières cibles';
  @override String get academicGoals => 'Objectifs académiques / Carrière';
  @override String get academicGoalsHint => 'Décris tes aspirations futures…';
  @override String get uploadCV => 'Télécharger le CV';
  @override String get uploadPhoto => 'Télécharger la photo';
  @override String get selectCvFile => 'Sélectionner mon CV';
  @override String get cvSupportedFormats => 'Formats acceptés : PDF, DOC, DOCX (max 10 Mo)';
  @override String get changePhoto => 'Changer la photo';
  @override String get profilePhotoAndCv => 'Photo de profil & CV';
  @override String get profilePhotoAndCvDesc => 'Télécharge ces fichiers pour activer la revue de CV et les listes de contrôle.';
  @override String get personalInfo => 'Informations personnelles';
  @override String get personalInfoDesc => 'Aide-nous à vérifier ton éligibilité aux opportunités académiques régionales.';
  @override String get academicProfile => 'Profil académique';
  @override String get academicProfileDesc => 'Fournis tes résultats académiques pour correspondre aux exigences des diplômes.';
  @override String get preferencesAndLanguages => 'Préférences & Langues';
  @override String get preferencesAndLanguagesDesc => 'Indique où tu veux étudier et les langues que tu parles.';
  @override String get targetStudyCountries => 'Pays d\'études souhaités (sélection multiple)';
  @override String get targetStudyFields => 'Filières souhaitées (sélection multiple)';
  @override String get back => 'Retour';
  @override String get finish => 'Terminer';
  @override String get saving => 'Enregistrement…';
  @override String get otherLanguages => 'Autres langues maîtrisées';
  @override String get addLanguage => '+ Ajouter une langue';
  @override String get languageName => 'Langue';
  @override String get proficiencyLevel => 'Niveau de maîtrise';
  @override String get selectLanguage => 'Sélectionner une langue';
  @override String get selectLevel => 'Sélectionner le niveau';
  @override String get remove => 'Supprimer';

  // Navigation
  @override String get discover => 'Découvrir';
  @override String get dashboard => 'Tableau de bord';
  @override String get aiAssistant => 'Fly Assistant';
  @override String get applications => 'Candidatures';
  @override String get profile => 'Profil';

  // Dashboard
  @override String get totalMatches => 'Total Matchs';
  @override String get savedScholarships => 'Sauvegardées';
  @override String get activeApplications => 'En cours';
  @override String get avgCompatibility => 'Match moyen';
  @override String get myScholarships => 'Mes Bourses';
  @override String get priorityScholarships => 'Priorité';
  @override String get recentActivity => 'Activité récente';

  // Swipe
  @override String get noMoreScholarships => 'Plus de bourses disponibles !';
  @override String get noMoreDesc => 'Reviens plus tard pour de nouvelles opportunités.';
  @override String get compatibility => 'Match';

  // Scholarship
  @override String get deadline => 'Échéance';
  @override String get fundingType => 'Financement';
  @override String get degreeLevel => 'Niveau';
  @override String get startApplication => 'Commencer la candidature';
  @override String get viewDetails => 'Voir les détails';

  // AI Assistant
  @override String get flyAssistant => 'Fly Assistant';
  @override String get askAnything => 'Pose-moi n\'importe quelle question…';
  @override String get assistantWelcome =>
      'Bonjour ! Je suis Fly Assistant\n\nJe peux t\'aider avec :\n• Révision de CV\n• Lettres de motivation\n• Rédaction de SOP\n• Préparation aux entretiens\n• Stratégie de bourses\n\nComment puis-je t\'aider aujourd\'hui ?';

  // Application
  @override String get applicationProgress => 'Avancement de la candidature';
  @override String get checklist => 'Liste de contrôle';

  // Settings
  @override String get settings => 'Paramètres';
  @override String get account => 'Compte';
  @override String get editProfile => 'Modifier le profil';
  @override String get editProfileSub => 'Mettre à jour les objectifs et niveaux de langues';
  @override String get notifications => 'Notifications';
  @override String get pushNotifications => 'Notifications push';
  @override String get emailUpdates => 'Mises à jour par e-mail';
  @override String get privacyAndData => 'Confidentialité & Données';
  @override String get anonymousAnalytics => 'Statistiques anonymes';
  @override String get privacyPolicy => 'Politique de confidentialité';
  @override String get termsOfService => 'Conditions d\'utilisation';
  @override String get logOut => 'Se déconnecter';
  @override String get appLanguage => 'Langue de l\'application';
  @override String get french => 'Français';
  @override String get english => 'English';
  @override String get privacyPolicyContent =>
      'Tes informations de profil étudiant sont sauvegardées de manière sécurisée sur les serveurs Supabase et utilisées uniquement pour évaluer les critères de correspondance avec les bourses régionales.';
  @override String get termsOfServiceContent =>
      'En utilisant Fly AI, tu consens à nos processus automatisés d\'éligibilité et de mise en correspondance avec les bourses.';
  @override String get close => 'Fermer';

  // Errors
  @override String get genericError => 'Une erreur s\'est produite. Veuillez réessayer.';
  @override String get noInternet => 'Pas de connexion internet.';
  @override String get invalidEmail => 'Veuillez saisir une adresse e-mail valide.';
  @override String get fieldRequired => 'Ce champ est requis.';
  @override String get uploadPhotoFailed => 'L\'upload de la photo a échoué. Le profil a été sauvegardé sans photo.';
  @override String get uploadCvFailed => 'L\'upload du CV a échoué. Le profil a été sauvegardé sans CV.';
  @override String get profileSavedWithoutFiles => 'Profil sauvegardé. Certains fichiers n\'ont pas pu être téléchargés.';
}
