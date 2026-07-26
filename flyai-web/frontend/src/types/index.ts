export interface UserProfile {
  id: string;
  fullName: string;
  email: string;
  photoUrl?: string;
  degreeLevel: string; // e.g. 'master', 'doctorat', 'licence' - NIVEAU ACTUEL
  targetDegreeLevel?: string; // e.g. 'master', 'doctorat', 'licence' - NIVEAU VISE (pour le matching)
  fieldOfStudy: string; // e.g. 'Informatique', 'Intelligence Artificielle', 'Génie Civil'
  nationality: string;
  targetCountries: string[]; // e.g. ['France', 'Allemagne', 'Canada']
  budgetMax: number;
  gpa: number;
  languages: {
    english?: string;
    french?: string;
    german?: string;
    spanish?: string;
  };
  skills: string[];
  cvUrl?: string;
  bio?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface Scholarship {
  id: string;
  titre: string;
  url: string;
  deadline?: string | null;
  deadline_raw?: string;
  pays_destination: string[];
  niveau_etude: string[];
  financement: 'TOTAL' | 'PARTIEL' | 'INCONNU';
  domaines: string[];
  langues_requises?: string[];
  nationalites_eligibles?: string[];
  description: string;
  avantages?: string[];
  criteres?: string[];
  lien_candidature?: string;
  image_url?: string;
  date_publication?: string;
  source?: string;
  active: boolean;
  matchScore?: number;
  matchBreakdown?: MatchBreakdown;
}

export interface MatchBreakdown {
  overallScore: number;
  degreeMatch: boolean;
  degreeScore: number;
  domainMatch: boolean;
  domainScore: number;
  countryMatch: boolean;
  countryScore: number;
  fundingMatch: boolean;
  fundingScore: number;
  nationalityMatch: boolean;
  nationalityScore: number;
  reasons: string[];
}

export interface SwipeRecord {
  id: string;
  userId: string;
  bourseId: string;
  direction: 'right' | 'left' | 'superlike';
  score: number;
  createdAt: string;
}

export interface Application {
  id: string;
  userId: string;
  bourseId: string;
  bourse?: Scholarship;
  status: 'draft' | 'submitted' | 'under_review' | 'accepted' | 'rejected';
  category?: 'favoris' | 'flyagent' | 'standard'; // Type de candidature
  checklist: {
    cv_uploaded: boolean;
    motivation_letter: boolean;
    transcripts: boolean;
    recommendation_letters: boolean;
    language_test?: boolean;
  };
  notes: string;
  deadline?: string;
  applicationUrl?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ChatSession {
  id: string;
  userId: string;
  title: string;
  createdAt: string;
  updatedAt?: string;
}

export interface ChatMessage {
  id: string;
  sessionId: string;
  sender: 'user' | 'assistant';
  content: string;
  context?: Record<string, any>;
  createdAt: string;
}

export interface ForumPost {
  id: string;
  userId: string;
  authorName: string;
  authorAvatar: string;
  content: string;
  tags: string[];
  likesCount: number;
  commentsCount: number;
  userHasLiked?: boolean;
  createdAt: string;
}

export interface DirectMessage {
  id: string;
  senderId: string;
  receiverId: string;
  content: string;
  read: boolean;
  createdAt: string;
}
