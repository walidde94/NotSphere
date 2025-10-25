import { create } from 'zustand';
import api from '../lib/api';
import { Attachment } from '../lib/types';

interface AttachmentsState {
  attachments: Record<string, Attachment[]>;
  uploadAttachment: (noteId: string, file: File) => Promise<Attachment>;
  deleteAttachment: (id: string, noteId: string) => Promise<void>;
  setAttachments: (noteId: string, items: Attachment[]) => void;
}

export const useAttachmentsStore = create<AttachmentsState>((set, get) => ({
  attachments: {},
  setAttachments: (noteId, items) =>
    set({
      attachments: {
        ...get().attachments,
        [noteId]: items
      }
    }),
  uploadAttachment: async (noteId, file) => {
    const form = new FormData();
    form.append('file', file);
    const csrfToken = document.cookie
      .split('; ')
      .find((row) => row.startsWith('notsphere_csrf='))?.split('=')[1];
    const response = await fetch(`/api/v1/notes/${noteId}/attachments`, {
      method: 'POST',
      body: form,
      credentials: 'include',
      headers: csrfToken ? { 'X-CSRF-Token': csrfToken } : undefined
    });
    if (!response.ok) {
      throw new Error(await response.text());
    }
    const data = (await response.json()) as { attachment: Attachment };
    set({
      attachments: {
        ...get().attachments,
        [noteId]: [...(get().attachments[noteId] ?? []), data.attachment]
      }
    });
    return data.attachment;
  },
  deleteAttachment: async (id, noteId) => {
    await api(`/api/v1/attachments/${id}`, { method: 'DELETE' });
    set({
      attachments: {
        ...get().attachments,
        [noteId]: (get().attachments[noteId] ?? []).filter((attachment) => attachment.id !== id)
      }
    });
  }
}));
