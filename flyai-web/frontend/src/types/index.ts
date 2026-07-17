export interface UserProfile {
  id: string;
  fullName: string;
  photoUrl?: string;
  nationality?: string;
  degreeLevel?: string;
  fieldOfStudy?: string;
  cvUrl?: string;
  createdAt: string;
}

export interface Scholarship {
  id: string;
  title: string;
  provider: string;
  url: string;
  country: string[];
  degreeLevel: string[];
  fundingType: 'TOTAL' | 'PARTIEL' | 'INCONNU';
  domaines: string[];
  description: string;
  avantages: string[];
  criteres: string[];
  deadline?: string;
  imageUrl?: string;
  active: boolean;
}

export interface ChatMessage {
  id: string;
  sessionId: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: string;
}

export interface ChatSession {
  id: string;
  title: string;
  createdAt: string;
}

export interface ApplicationTask {
  id: string;
  title: string;
  category: 'document' | 'test' | 'online' | 'other';
  description: string;
  isCompleted: boolean;
}

export interface Application {
  id: string;
  scholarshipId: string;
  scholarship?: Scholarship;
  status: 'draft' | 'in_progress' | 'submitted' | 'accepted' | 'rejected';
  progress: number;
  checklist: Record<string, boolean>;
  createdAt: string;
}
