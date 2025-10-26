import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { formatDistanceToNow } from 'date-fns';
import { toast } from 'sonner';
import { useGroupsStore } from '../store/groups';
import { useNotesStore } from '../store/notes';
import { useAuthStore } from '../store/auth';
import GroupSidebar from '../components/groups/GroupSidebar';
import NotesPanel from '../components/notes/NotesPanel';
import NoteEditor from '../components/editor/NoteEditor';
import { useEditorStore } from '../store/editor';
import { useAttachmentsStore } from '../store/attachments';
import { useOfflineSync } from '../hooks/useOfflineSync';

const DashboardPage = () => {
  const navigate = useNavigate();
  useOfflineSync();
  const { user, fetchMe } = useAuthStore();
  const { groups, fetchGroups } = useGroupsStore();
  const { notes, fetchNotes, activeNoteId, setActiveNote, createNote } = useNotesStore();
  const { setAttachments } = useAttachmentsStore();
  const { status, lastSavedAt } = useEditorStore();
  const [search, setSearch] = useState('');
  const [activeGroupId, setActiveGroupId] = useState<string | null>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    fetchMe().catch(() => navigate('/auth'));
  }, [fetchMe, navigate]);

  useEffect(() => {
    if (user) {
      fetchGroups().catch((error) => {
        console.error(error);
        toast.error('Unable to load groups');
      });
    }
  }, [user, fetchGroups]);

  useEffect(() => {
    if (groups.length > 0 && !activeGroupId) {
      setActiveGroupId(groups[0].id);
    }
  }, [groups, activeGroupId]);

  const activeGroup = useMemo(
    () => (activeGroupId ? groups.find((group) => group.id === activeGroupId) ?? null : null),
    [groups, activeGroupId]
  );

  useEffect(() => {
    if (!activeGroup) return;
    const timeout = window.setTimeout(() => {
      fetchNotes(activeGroup.id, { query: search || undefined }).catch((error) => {
        if (navigator.onLine) {
          console.error(error);
          toast.error('Unable to load notes');
        }
      });
    }, 250);
    return () => window.clearTimeout(timeout);
  }, [activeGroup, search, fetchNotes]);

  useEffect(() => {
    if (!activeNoteId && notes.length > 0) {
      setActiveNote(notes[0].id);
    }
  }, [notes, activeNoteId, setActiveNote]);

  const filteredNotes = useMemo(() => {
    if (!search) return notes;
    const term = search.toLowerCase();
    return notes.filter((note) =>
      `${note.title} ${note.plainPreview}`.toLowerCase().includes(term)
    );
  }, [notes, search]);

  const handleSelectGroup = useCallback(
    async (groupId: string) => {
      setActiveGroupId(groupId);
      setActiveNote(null);
      try {
        await fetchNotes(groupId, { query: search || undefined });
      } catch (error) {
        if (navigator.onLine) {
          console.error(error);
          toast.error('Unable to load notes');
        }
      }
    },
    [fetchNotes, search, setActiveNote]
  );

  const handleCreateNote = useCallback(async () => {
    if (!activeGroup) return;
    const note = await createNote(activeGroup.id, { title: 'Untitled note', content: {} });
    setAttachments(note.id, []);
    setActiveNote(note.id);
  }, [activeGroup, createNote, setAttachments, setActiveNote]);

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      const isMeta = navigator.platform.includes('Mac');
      const comboActive = (isMeta && event.metaKey) || (!isMeta && event.ctrlKey);
      if (!comboActive) return;
      const key = event.key.toLowerCase();
      if (key === 'n') {
        event.preventDefault();
        void handleCreateNote();
      } else if (key === 'k') {
        event.preventDefault();
        searchInputRef.current?.focus();
      } else if (key === 's') {
        event.preventDefault();
        window.dispatchEvent(new Event('notsphere:save'));
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [handleCreateNote]);

  return (
    <div className="flex w-full flex-1 overflow-hidden">
      <GroupSidebar activeGroupId={activeGroup?.id} onSelectGroup={handleSelectGroup} />
      <div className="flex w-full flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-slate-800 bg-slate-900/40 px-6 py-4">
          <div>
            <h1 className="text-xl font-semibold text-cyberpunk">Welcome back{user ? `, ${user.name}` : ''}!</h1>
            <p className="text-sm text-slate-300">
              Status: <span className="font-medium text-white">{status}</span>
              {lastSavedAt && status === 'saved' && (
                <span className="ml-2 text-xs text-slate-400">
                  Saved {formatDistanceToNow(new Date(lastSavedAt), { addSuffix: true })}
                </span>
              )}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <input
              placeholder="Search notes"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              ref={searchInputRef}
              className="rounded-md border border-slate-700 bg-slate-950 px-3 py-1"
            />
            <button
              className="rounded-md bg-cyberpunk px-4 py-2 font-medium text-slate-950"
              onClick={handleCreateNote}
            >
              New note
            </button>
          </div>
        </header>
        <main className="flex flex-1 overflow-hidden">
          <NotesPanel notes={filteredNotes} searchTerm={search} />
          <NoteEditor />
        </main>
      </div>
    </div>
  );
};

export default DashboardPage;
