import { create } from 'zustand';

interface EditorState {
  status: 'idle' | 'saving' | 'saved' | 'offline';
  setStatus: (status: EditorState['status']) => void;
}

export const useEditorStore = create<EditorState>((set) => ({
  status: 'idle',
  setStatus: (status) => set({ status })
}));
