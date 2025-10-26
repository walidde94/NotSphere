import { openDB, DBSchema } from 'idb';
import type { Group, Note } from './types';

interface NotSphereDB extends DBSchema {
  groups: {
    key: string;
    value: Group;
  };
  notes: {
    key: string;
    value: Note & { groupId: string };
  };
  pending: {
    key: string;
    value: {
      id: string;
      payload: Partial<Note> & { clientUpdatedAt?: string };
      updatedAt: string;
      groupId: string;
    };
  };
}

const dbPromise = openDB<NotSphereDB>('notsphere', 1, {
  upgrade(db) {
    if (!db.objectStoreNames.contains('groups')) {
      db.createObjectStore('groups', { keyPath: 'id' });
    }
    if (!db.objectStoreNames.contains('notes')) {
      db.createObjectStore('notes', { keyPath: 'id' });
    }
    if (!db.objectStoreNames.contains('pending')) {
      db.createObjectStore('pending', { keyPath: 'id' });
    }
  }
});

export const cacheGroups = async (groups: Group[]) => {
  const db = await dbPromise;
  const tx = db.transaction('groups', 'readwrite');
  await Promise.all(groups.map((group) => tx.store.put(group)));
  await tx.done;
};

export const getCachedGroups = async () => {
  const db = await dbPromise;
  return db.getAll('groups');
};

export const cacheNotes = async (groupId: string, notes: Note[]) => {
  const db = await dbPromise;
  const tx = db.transaction('notes', 'readwrite');
  await Promise.all(notes.map((note) => tx.store.put({ ...note, groupId })));
  await tx.done;
};

export const getCachedNotes = async (groupId: string) => {
  const db = await dbPromise;
  const all = await db.getAll('notes');
  return all
    .filter((note) => note.groupId === groupId)
    .map(({ groupId: _groupId, ...note }) => note);
};

export const cacheNote = async (note: Note) => {
  const db = await dbPromise;
  const tx = db.transaction('notes', 'readwrite');
  await tx.store.put({ ...note, groupId: note.groupId });
  await tx.done;
};

export const queuePendingUpdate = async (
  id: string,
  payload: Partial<Note> & { clientUpdatedAt?: string },
  groupId: string
) => {
  const db = await dbPromise;
  const tx = db.transaction('pending', 'readwrite');
  await tx.store.put({ id, payload, updatedAt: new Date().toISOString(), groupId });
  await tx.done;
};

export const removePendingUpdate = async (id: string) => {
  const db = await dbPromise;
  const tx = db.transaction('pending', 'readwrite');
  await tx.store.delete(id);
  await tx.done;
};

export const getPendingUpdates = async () => {
  const db = await dbPromise;
  return db.getAll('pending');
};
