import { create } from 'zustand';

interface EditorState {
  status: 'idle' | 'saving' | 'saved' | 'offline';
  lastSavedAt: string | null;
  setStatus: (status: EditorState['status']) => void;
  setLastSavedAt: (timestamp: string | null) => void;
}

export const useEditorStore = create<EditorState>((set) => ({
  status: 'idle',
  lastSavedAt: null,
  setStatus: (status) => set({ status }),
  setLastSavedAt: (timestamp) => set({ lastSavedAt: timestamp })
}));
