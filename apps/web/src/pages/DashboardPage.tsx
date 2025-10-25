import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useGroupsStore } from '../store/groups';
import { useNotesStore } from '../store/notes';
import { useAuthStore } from '../store/auth';
import GroupSidebar from '../components/groups/GroupSidebar';
import NotesPanel from '../components/notes/NotesPanel';
import NoteEditor from '../components/editor/NoteEditor';
import { useEditorStore } from '../store/editor';
import { useAttachmentsStore } from '../store/attachments';
import { toast } from 'sonner';

const DashboardPage = () => {
  const navigate = useNavigate();
  const { user, fetchMe } = useAuthStore();
  const { groups, fetchGroups } = useGroupsStore();
  const { notes, fetchNotes, activeNoteId, setActiveNote, createNote } = useNotesStore();
  const { setAttachments } = useAttachmentsStore();
  const { status } = useEditorStore();
  const [search, setSearch] = useState('');

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

  const activeGroup = useMemo(() => groups[0], [groups]);

  useEffect(() => {
    if (activeGroup) {
      fetchNotes(activeGroup.id).catch((error) => {
        console.error(error);
        toast.error('Unable to load notes');
      });
    }
  }, [activeGroup, fetchNotes]);

  useEffect(() => {
    if (!activeNoteId && notes.length > 0) {
      setActiveNote(notes[0].id);
    }
  }, [notes, activeNoteId, setActiveNote]);

  const filteredNotes = useMemo(() => {
    if (!search) return notes;
    const term = search.toLowerCase();
    return notes.filter((note) => note.title.toLowerCase().includes(term));
  }, [notes, search]);

  const handleCreateNote = async () => {
    if (!activeGroup) return;
    const note = await createNote(activeGroup.id, { title: 'Untitled note', content: {} });
    setAttachments(note.id, []);
    setActiveNote(note.id);
  };

  return (
    <div className="flex w-full flex-1 overflow-hidden">
      <GroupSidebar activeGroupId={activeGroup?.id} />
      <div className="flex w-full flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-slate-800 bg-slate-900/40 px-6 py-4">
          <div>
            <h1 className="text-xl font-semibold text-cyberpunk">Welcome back{user ? `, ${user.name}` : ''}!</h1>
            <p className="text-sm text-slate-300">Status: {status}</p>
          </div>
          <div className="flex items-center gap-3">
            <input
              placeholder="Search notes"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
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
          <NotesPanel notes={filteredNotes} />
          <NoteEditor />
        </main>
      </div>
    </div>
  );
};

export default DashboardPage;
