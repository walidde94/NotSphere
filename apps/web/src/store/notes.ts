import { create } from 'zustand';
import api from '../lib/api';
import { cacheNote, cacheNotes, getCachedNotes, getPendingUpdates, queuePendingUpdate, removePendingUpdate } from '../lib/db';
import { Note } from '../lib/types';

interface PresenceUser {
  userId: string;
  name: string;
}

type ConflictEntry = {
  local: Note;
  remote: Note;
};

type NoteUpdatePayload = {
  title?: string;
  content?: Note['content'];
  plainPreview?: string;
  isPinned?: boolean;
};

interface NotesState {
  notes: Note[];
  activeNoteId: string | null;
  saving: boolean;
  pendingUpdates: Record<string, Partial<Note> & { clientUpdatedAt?: string }>;
  conflicts: Record<string, ConflictEntry>;
  presence: Record<string, PresenceUser[]>;
  pagination: Record<string, { page: number; totalPages: number; total: number; limit: number }>;
  fetchNotes: (groupId: string, options?: { query?: string; page?: number }) => Promise<void>;
  fetchNote: (noteId: string) => Promise<Note>;
  createNote: (groupId: string, payload: { title?: string; content?: any }) => Promise<Note>;
  updateNote: (
    id: string,
    payload: NoteUpdatePayload
  ) => Promise<{ note?: Note; conflict?: ConflictEntry; offline?: boolean }>;
  deleteNote: (id: string) => Promise<void>;
  setActiveNote: (id: string | null) => void;
  setPresence: (noteId: string, users: PresenceUser[]) => void;
  syncPending: () => Promise<void>;
  resolveConflict: (noteId: string, strategy: 'local' | 'remote') => Promise<void>;
  applyRealtimeUpdate: (noteId: string, update: Partial<Note>) => void;
}

const omitKey = <T>(record: Record<string, T>, key: string) => {
  const { [key]: _removed, ...rest } = record;
  return rest;
};

export const useNotesStore = create<NotesState>((set, get) => ({
  notes: [],
  activeNoteId: null,
  saving: false,
  pendingUpdates: {},
  conflicts: {},
  presence: {},
  pagination: {},
  fetchNotes: async (groupId, options) => {
    try {
      const params = new URLSearchParams();
      if (options?.query) params.append('query', options.query);
      if (options?.page) params.append('page', String(options.page));
      const query = params.toString();
      const data = await api<{ notes: Note[]; pagination?: { page: number; totalPages: number; total: number; limit: number } }>(
        `/api/v1/groups/${groupId}/notes${query ? `?${query}` : ''}`
      );
      set((state) => ({
        notes: data.notes,
        pagination: data.pagination ? { ...state.pagination, [groupId]: data.pagination } : state.pagination
      }));
      await cacheNotes(groupId, data.notes);
    } catch (error) {
      const cached = await getCachedNotes(groupId);
      if (cached.length > 0) {
        set({ notes: cached });
      }
      throw error;
    }
  },
  fetchNote: async (noteId) => {
    try {
      const data = await api<{ note: Note }>(`/api/v1/notes/${noteId}`);
      await cacheNote(data.note);
      set((state) => ({
        activeNoteId: data.note.id,
        notes: state.notes.some((note) => note.id === data.note.id)
          ? state.notes.map((note) => (note.id === data.note.id ? data.note : note))
          : [data.note, ...state.notes]
      }));
      return data.note;
    } catch (error) {
      const existing = get().notes.find((note) => note.id === noteId);
      if (existing) {
        set({ activeNoteId: noteId });
        return existing;
      }
      throw error;
    }
  },
  createNote: async (groupId, payload) => {
    const data = await api<{ note: Note }>(`/api/v1/groups/${groupId}/notes`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
    await cacheNote(data.note);
    set((state) => ({ notes: [data.note, ...state.notes], activeNoteId: data.note.id }));
    return data.note;
  },
  updateNote: async (id, payload) => {
    const existing = get().notes.find((note) => note.id === id);
    if (!existing) {
      throw new Error('Note not loaded');
    }
    const local: Note = {
      ...existing,
      ...payload,
      updatedAt: new Date().toISOString()
    };

    set((state) => ({
      saving: true,
      notes: state.notes.map((note) => (note.id === id ? local : note))
    }));

    try {
      const data = await api<{ note: Note; conflict?: boolean; previous?: Note }>(`/api/v1/notes/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ ...payload, clientUpdatedAt: existing.updatedAt })
      });
      await cacheNote(data.note);
      await removePendingUpdate(id);
      set((state) => ({
        notes: state.notes.map((note) => (note.id === id ? data.note : note)),
        saving: false,
        pendingUpdates: omitKey(state.pendingUpdates, id),
        conflicts: data.conflict && data.previous
          ? { ...state.conflicts, [id]: { local, remote: data.previous } }
          : omitKey(state.conflicts, id)
      }));
      return {
        note: data.note,
        conflict: data.conflict && data.previous ? { local, remote: data.previous } : undefined,
        offline: false
      };
    } catch (error) {
      await queuePendingUpdate(id, { ...payload, clientUpdatedAt: existing.updatedAt }, existing.groupId);
      await cacheNote(local);
      set((state) => ({
        saving: false,
        pendingUpdates: {
          ...state.pendingUpdates,
          [id]: { ...state.pendingUpdates[id], ...payload, clientUpdatedAt: existing.updatedAt }
        }
      }));
      const offlineError = error instanceof Error ? error : new Error('Network error');
      (offlineError as Error & { offline?: boolean }).offline = true;
      throw offlineError;
    }
  },
  deleteNote: async (id) => {
    await api(`/api/v1/notes/${id}`, { method: 'DELETE' });
    set((state) => ({
      notes: state.notes.filter((note) => note.id !== id),
      activeNoteId: state.activeNoteId === id ? null : state.activeNoteId,
      pendingUpdates: omitKey(state.pendingUpdates, id),
      conflicts: omitKey(state.conflicts, id)
    }));
    await removePendingUpdate(id);
  },
  setActiveNote: (id) => set({ activeNoteId: id }),
  setPresence: (noteId, users) =>
    set((state) => ({
      presence: {
        ...state.presence,
        [noteId]: users
      }
    })),
  syncPending: async () => {
    const pending = await getPendingUpdates();
    for (const entry of pending) {
      try {
        const response = await api<{ note: Note; conflict?: boolean; previous?: Note }>(`/api/v1/notes/${entry.id}`, {
          method: 'PATCH',
          body: JSON.stringify({ ...entry.payload, clientUpdatedAt: entry.payload.clientUpdatedAt })
        });
        await cacheNote(response.note);
        await removePendingUpdate(entry.id);
        set((state) => ({
          notes: state.notes.map((note) => (note.id === entry.id ? response.note : note)),
          pendingUpdates: omitKey(state.pendingUpdates, entry.id),
          conflicts: response.conflict && response.previous
            ? { ...state.conflicts, [entry.id]: { local: state.notes.find((note) => note.id === entry.id) ?? response.note, remote: response.previous } }
            : omitKey(state.conflicts, entry.id)
        }));
      } catch (error) {
        console.error('Failed to sync pending note', entry.id, error);
      }
    }
  },
  resolveConflict: async (noteId, strategy) => {
    const conflict = get().conflicts[noteId];
    if (!conflict) return;

    if (strategy === 'remote') {
      await cacheNote(conflict.remote);
      await removePendingUpdate(noteId);
      set((state) => ({
        notes: state.notes.map((note) => (note.id === noteId ? conflict.remote : note)),
        conflicts: omitKey(state.conflicts, noteId)
      }));
      return;
    }

    try {
      const response = await api<{ note: Note }>(`/api/v1/notes/${noteId}`, {
        method: 'PATCH',
        body: JSON.stringify({
          title: conflict.local.title,
          content: conflict.local.content,
          plainPreview: conflict.local.plainPreview,
          isPinned: conflict.local.isPinned,
          clientUpdatedAt: conflict.remote.updatedAt
        })
      });
      await cacheNote(response.note);
      await removePendingUpdate(noteId);
      set((state) => ({
        notes: state.notes.map((note) => (note.id === noteId ? response.note : note)),
        conflicts: omitKey(state.conflicts, noteId)
      }));
    } catch (error) {
      console.error('Failed to resolve conflict for note', noteId, error);
    }
  },
  applyRealtimeUpdate: (noteId, update) =>
    set((state) => ({
      notes: state.notes.map((note) => (note.id === noteId ? { ...note, ...update } : note))
    }))
}));
