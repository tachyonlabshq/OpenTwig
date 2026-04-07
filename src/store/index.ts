import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type SidebarSelection = 'documents' | 'branches' | 'citations' | 'activity' | 'settings';

interface AppState {
  hasCompletedOnboarding: boolean;
  authorName: string;
  authorEmail: string;
  selectedProjectId: string | null;
  sidebarSelection: SidebarSelection;
  setOnboardingComplete: () => void;
  resetOnboarding: () => void;
  setAuthor: (name: string, email: string) => void;
  setSelectedProject: (id: string | null) => void;
  setSidebarSelection: (sel: SidebarSelection) => void;
}

export const useStore = create<AppState>()(
  persist(
    (set) => ({
      hasCompletedOnboarding: false,
      authorName: '',
      authorEmail: '',
      selectedProjectId: null,
      sidebarSelection: 'documents',
      setOnboardingComplete: () => set({ hasCompletedOnboarding: true }),
      resetOnboarding: () =>
        set({
          hasCompletedOnboarding: false,
          selectedProjectId: null,
        }),
      setAuthor: (authorName, authorEmail) => set({ authorName, authorEmail }),
      setSelectedProject: (selectedProjectId) => set({ selectedProjectId }),
      setSidebarSelection: (sidebarSelection) => set({ sidebarSelection }),
    }),
    { name: 'opentwig-app' },
  ),
);
