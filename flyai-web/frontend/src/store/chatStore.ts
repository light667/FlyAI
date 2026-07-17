import { create } from "zustand";
import { ChatMessage, ChatSession, ApplicationTask, Scholarship } from "../types";

interface ChatState {
  // FlyAssistant (General RAG Chat)
  assistantSessions: ChatSession[];
  assistantMessages: ChatMessage[];
  activeAssistantSessionId: string | null;
  isAssistantSending: boolean;
  
  // FlyAgent (Coaching Chat)
  activeCoachingScholarship: Scholarship | null;
  coachingMessages: ChatMessage[];
  coachingTasks: ApplicationTask[];
  coachingPhase: 'idle' | 'briefing' | 'awaiting_confirmation' | 'coaching';
  isCoachingSending: boolean;

  // Actions
  setAssistantSessions: (sessions: ChatSession[]) => void;
  setAssistantMessages: (messages: ChatMessage[]) => void;
  setActiveAssistantSessionId: (id: string | null) => void;
  setAssistantSending: (sending: boolean) => void;
  addAssistantMessage: (msg: ChatMessage) => void;

  setCoachingScholarship: (scholarship: Scholarship | null) => void;
  setCoachingMessages: (messages: ChatMessage[]) => void;
  setCoachingTasks: (tasks: ApplicationTask[]) => void;
  toggleCoachingTask: (taskId: string) => void;
  setCoachingPhase: (phase: ChatState["coachingPhase"]) => void;
  setCoachingSending: (sending: boolean) => void;
  addCoachingMessage: (msg: ChatMessage) => void;
  resetCoaching: () => void;
}

export const useChatStore = create<ChatState>((set) => ({
  // Defaults
  assistantSessions: [],
  assistantMessages: [],
  activeAssistantSessionId: null,
  isAssistantSending: false,

  activeCoachingScholarship: null,
  coachingMessages: [],
  coachingTasks: [],
  coachingPhase: 'idle',
  isCoachingSending: false,

  // Assistant Actions
  setAssistantSessions: (sessions) => set({ assistantSessions: sessions }),
  setAssistantMessages: (messages) => set({ assistantMessages: messages }),
  setActiveAssistantSessionId: (id) => set({ activeAssistantSessionId: id }),
  setAssistantSending: (sending) => set({ isAssistantSending: sending }),
  addAssistantMessage: (msg) =>
    set((state) => ({ assistantMessages: [...state.assistantMessages, msg] })),

  // Coaching Actions
  setCoachingScholarship: (scholarship) =>
    set({
      activeCoachingScholarship: scholarship,
      coachingPhase: scholarship ? 'briefing' : 'idle',
    }),
  setCoachingMessages: (messages) => set({ coachingMessages: messages }),
  setCoachingTasks: (tasks) => set({ coachingTasks: tasks }),
  toggleCoachingTask: (taskId) =>
    set((state) => ({
      coachingTasks: state.coachingTasks.map((t) =>
        t.id === taskId ? { ...t, isCompleted: !t.isCompleted } : t
      ),
    })),
  setCoachingPhase: (phase) => set({ coachingPhase: phase }),
  setCoachingSending: (sending) => set({ isCoachingSending: sending }),
  addCoachingMessage: (msg) =>
    set((state) => ({ coachingMessages: [...state.coachingMessages, msg] })),
  resetCoaching: () =>
    set({
      activeCoachingScholarship: null,
      coachingMessages: [],
      coachingTasks: [],
      coachingPhase: 'idle',
      isCoachingSending: false,
    }),
}));
