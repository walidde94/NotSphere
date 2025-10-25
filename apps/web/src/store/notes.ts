import { create } from 'zustand';
import api from '../lib/api';
import { Note } from '../lib/types';

interface NotesState {
  notes: Note[];
  activeNoteId: string | null;
  saving: boolean;
  fetchNotes: (groupId: string) => Promise<void>;
  fetchNote: (noteId: string) => Promise<Note>;
  createNote: (groupId: string, payload: { title?: string; content?: any }) => Promise<Note>;
  updateNote: (id: string, payload: Partial<Note>) => Promise<Note>;
  deleteNote: (id: string) => Promise<void>;
  setActiveNote: (id: string | null) => void;
}

export const useNotesStore = create<NotesState>((set, get) => ({
  notes: [],
  activeNoteId: null,
  saving: false,
  fetchNotes: async (groupId) => {
    const data = await api<{ notes: Note[] }>(`/api/v1/groups/${groupId}/notes`);
    set({ notes: data.notes });
  },
  fetchNote: async (noteId) => {
    const data = await api<{ note: Note }>(`/api/v1/notes/${noteId}`);
    set({
      activeNoteId: data.note.id,
      notes: get().notes.map((note) => (note.id === data.note.id ? data.note : note))
    });
    return data.note;
  },
  createNote: async (groupId, payload) => {
    const data = await api<{ note: Note }>(`/api/v1/groups/${groupId}/notes`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
    set({ notes: [data.note, ...get().notes], activeNoteId: data.note.id });
    return data.note;
  },
  updateNote: async (id, payload) => {
    set({ saving: true });
    const data = await api<{ note: Note }>(`/api/v1/notes/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload)
    });
    set({
      notes: get().notes.map((note) => (note.id === id ? data.note : note)),
      saving: false
    });
    return data.note;
  },
  deleteNote: async (id) => {
    await api(`/api/v1/notes/${id}`, { method: 'DELETE' });
    set({
      notes: get().notes.filter((note) => note.id !== id),
      activeNoteId: get().activeNoteId === id ? null : get().activeNoteId
    });
  },
  setActiveNote: (id) => set({ activeNoteId: id })
}));
