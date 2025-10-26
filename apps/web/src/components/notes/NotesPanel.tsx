import { useMemo } from 'react';
import { Note } from '../../lib/types';
import { useNotesStore } from '../../store/notes';
import { useAttachmentsStore } from '../../store/attachments';
import { formatDistanceToNow } from 'date-fns';
import { Fragment } from 'react';

interface NotesPanelProps {
  notes: Note[];
  searchTerm?: string;
}

const NotesPanel = ({ notes, searchTerm }: NotesPanelProps) => {
  const { activeNoteId, setActiveNote, fetchNote } = useNotesStore();
  const { setAttachments } = useAttachmentsStore();

  const sortedNotes = useMemo(() => {
    return [...notes].sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
  }, [notes]);

  const highlight = (text: string) => {
    const term = searchTerm?.trim();
    if (!term) return text;
    const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const parts = text.split(new RegExp(`(${escaped})`, 'ig'));
    return parts.map((part, index) =>
      index % 2 === 1 ? (
        <span key={`${part}-${index}`} className="rounded bg-cyberpunk/30 px-1 text-cyberpunk">
          {part}
        </span>
      ) : (
        <Fragment key={`${part}-${index}`}>{part}</Fragment>
      )
    );
  };

  return (
    <div className="flex w-80 flex-col border-r border-slate-800 bg-slate-950/40">
      <header className="border-b border-slate-800 px-4 py-3 text-sm text-slate-400">
        Notes
      </header>
      <div className="flex-1 overflow-y-auto">
        {sortedNotes.map((note) => (
          <button
            key={note.id}
            onClick={async () => {
              try {
                const detailed = await fetchNote(note.id);
                setAttachments(note.id, detailed.attachments ?? []);
                setActiveNote(note.id);
              } catch (error) {
                console.error(error);
              }
            }}
            className={`w-full border-b border-slate-900 px-4 py-3 text-left transition hover:bg-slate-900/60 ${
              note.id === activeNoteId ? 'bg-slate-900/80 text-cyberpunk' : 'text-slate-200'
            }`}
          >
            <h3 className="text-sm font-semibold">{highlight(note.title || 'Untitled')}</h3>
            <p className="mt-1 line-clamp-2 text-xs text-slate-400">{highlight(note.plainPreview ?? '')}</p>
            <p className="mt-2 text-[10px] uppercase tracking-wide text-slate-500">
              Updated {formatDistanceToNow(new Date(note.updatedAt), { addSuffix: true })}
            </p>
          </button>
        ))}
        {sortedNotes.length === 0 && (
          <div className="p-6 text-sm text-slate-400">
            No notes yet. Use the New note button to get started.
          </div>
        )}
      </div>
    </div>
  );
};

export default NotesPanel;
