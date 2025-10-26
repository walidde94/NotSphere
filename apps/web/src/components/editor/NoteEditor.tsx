import { useCallback, useEffect, useMemo, useState } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Underline from '@tiptap/extension-underline';
import Highlight from '@tiptap/extension-highlight';
import Link from '@tiptap/extension-link';
import TaskList from '@tiptap/extension-task-list';
import TaskItem from '@tiptap/extension-task-item';
import { toast } from 'sonner';
import debounce from '../../lib/debounce';
import { notesSocket } from '../../lib/realtime';
import { useNotesStore } from '../../store/notes';
import { useEditorStore } from '../../store/editor';
import { useAttachmentsStore } from '../../store/attachments';
import { useAuthStore } from '../../store/auth';
import AttachmentPanel from '../attachments/AttachmentPanel';
import AudioRecorder from '../recorder/AudioRecorder';

const NoteEditor = () => {
  const activeNoteId = useNotesStore((state) => state.activeNoteId);
  const notes = useNotesStore((state) => state.notes);
  const updateNote = useNotesStore((state) => state.updateNote);
  const resolveConflict = useNotesStore((state) => state.resolveConflict);
  const conflicts = useNotesStore((state) => state.conflicts);
  const presenceMap = useNotesStore((state) => state.presence);
  const setPresence = useNotesStore((state) => state.setPresence);
  const applyRealtimeUpdate = useNotesStore((state) => state.applyRealtimeUpdate);
  const { setStatus, setLastSavedAt } = useEditorStore();
  const { uploadAttachment, setAttachments } = useAttachmentsStore();
  const { user } = useAuthStore();
  const [title, setTitle] = useState('');

  const note = useMemo(() => notes.find((n) => n.id === activeNoteId) ?? null, [notes, activeNoteId]);
  const conflict = note ? conflicts[note.id] : undefined;
  const presence = note ? presenceMap[note.id] ?? [] : [];

  const editor = useEditor({
    extensions: [StarterKit, Underline, Highlight, Link.configure({ openOnClick: false }), TaskList, TaskItem],
    content: note?.content ?? '<p>Select a note to start writing</p>'
  });

  useEffect(() => {
    if (!note || !editor) return;
    editor.commands.setContent(note.content ?? '<p></p>', false);
    setTitle(note.title ?? '');
    setAttachments(note.id, note.attachments ?? []);
  }, [note, editor, setAttachments]);

  useEffect(() => {
    if (!note || !user) return;
    const me = { userId: user.id, name: user.name };
    const applyPresence = (entry: typeof me) => {
      const current = useNotesStore.getState().presence[note.id] ?? [];
      const next = [...current.filter((item) => item.userId !== entry.userId), entry];
      setPresence(note.id, next);
    };

    applyPresence(me);
    notesSocket.emit('note:presence', { noteId: note.id, user: me });

    const handlePresence = (payload: { noteId: string; user: typeof me }) => {
      if (payload.noteId !== note.id) return;
      applyPresence(payload.user);
    };

    notesSocket.on('note:presence', handlePresence);
    return () => {
      notesSocket.off('note:presence', handlePresence);
      const current = useNotesStore.getState().presence[note.id] ?? [];
      setPresence(
        note.id,
        current.filter((item) => item.userId !== me.userId)
      );
    };
  }, [note, user, setPresence]);

  useEffect(() => {
    if (!note) return;

    notesSocket.emit('join', note.id);

    const handleContent = (payload: { noteId: string; content: any; plainPreview?: string; updatedAt?: string }) => {
      if (!editor || payload.noteId !== note.id) return;
      const incoming = JSON.stringify(payload.content);
      const existing = JSON.stringify(editor.getJSON());
      if (incoming === existing) return;
      editor.commands.setContent(payload.content, false);
      applyRealtimeUpdate(note.id, {
        content: payload.content,
        plainPreview: payload.plainPreview ?? note.plainPreview,
        updatedAt: payload.updatedAt ?? new Date().toISOString()
      });
    };

    const handleMeta = (payload: { noteId: string; update: Partial<Pick<NonNullable<typeof note>, 'title' | 'plainPreview' | 'isPinned'>> }) => {
      if (payload.noteId !== note.id) return;
      if (payload.update.title) {
        setTitle(payload.update.title);
      }
      applyRealtimeUpdate(note.id, payload.update as any);
    };

    notesSocket.on('note:content', handleContent);
    notesSocket.on('note:meta', handleMeta);

    return () => {
      notesSocket.off('note:content', handleContent);
      notesSocket.off('note:meta', handleMeta);
    };
  }, [note, editor, applyRealtimeUpdate]);

  const persistNote = useCallback(async () => {
    if (!note || !editor) return;
    const content = editor.getJSON();
    const plainPreview = editor.getText().slice(0, 200);
    try {
      setStatus('saving');
      const result = await updateNote(note.id, {
        title,
        content,
        plainPreview
      });
      if (result?.conflict) {
        toast.warning('We found newer edits on the server. Resolve the conflict below.');
      }
      setStatus('saved');
      setLastSavedAt(new Date().toISOString());
      notesSocket.emit('note:content', {
        noteId: note.id,
        content,
        plainPreview,
        updatedAt: new Date().toISOString()
      });
    } catch (error) {
      if ((error as { offline?: boolean }).offline) {
        toast.warning('You are offline. Changes will sync when reconnected.');
        setStatus('offline');
      } else {
        console.error(error);
        toast.error('Failed to save note');
        setStatus('idle');
      }
    }
  }, [note, editor, title, updateNote, setStatus, setLastSavedAt]);

  useEffect(() => {
    if (!editor || !note) return;
    const handler = debounce(() => {
      void persistNote();
    }, 800);

    editor.on('update', handler);
    return () => {
      editor.off('update', handler);
    };
  }, [editor, note, persistNote]);

  useEffect(() => {
    const manualSave = () => {
      void persistNote();
    };
    window.addEventListener('notsphere:save', manualSave as EventListener);
    return () => {
      window.removeEventListener('notsphere:save', manualSave as EventListener);
    };
  }, [persistNote]);

  const handleTitleBlur = useCallback(async () => {
    if (!note) return;
    const trimmed = title.trim();
    if (trimmed === note.title) return;
    try {
      setStatus('saving');
      await updateNote(note.id, { title: trimmed, plainPreview: note.plainPreview });
      setStatus('saved');
      setLastSavedAt(new Date().toISOString());
      notesSocket.emit('note:meta', { noteId: note.id, update: { title: trimmed } });
    } catch (error) {
      if ((error as { offline?: boolean }).offline) {
        toast.warning('Title updated offline. Will sync later.');
        setStatus('offline');
      } else {
        console.error(error);
        toast.error('Failed to update title');
        setStatus('idle');
      }
    }
  }, [note, title, updateNote, setStatus, setLastSavedAt]);

  if (!note) {
    return (
      <div className="flex flex-1 items-center justify-center bg-slate-950 text-slate-500">
        <p>Select a note to start writing.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col bg-slate-950">
      <div className="border-b border-slate-800 px-6 py-4">
        <div className="flex items-center justify-between gap-4">
          <input
            className="w-full border-none bg-transparent text-2xl font-semibold text-white outline-none"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Untitled"
            onBlur={handleTitleBlur}
          />
          {presence.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {presence.map((person) => (
                <span
                  key={person.userId}
                  className="rounded-full border border-cyberpunk/60 px-3 py-1 text-xs text-cyberpunk"
                >
                  {person.name}
                </span>
              ))}
            </div>
          )}
        </div>
        {conflict && (
          <div className="mt-4 rounded-md border border-amber-500/40 bg-amber-500/10 p-4 text-sm text-amber-100">
            <p className="font-semibold">Sync conflict detected</p>
            <p className="mt-1 text-amber-100/80">
              Another edit landed on the server while you were offline. Choose which version to keep.
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                className="rounded-md bg-amber-400 px-3 py-1 text-xs font-semibold text-slate-900"
                onClick={() => resolveConflict(note.id, 'remote')}
              >
                Use server version
              </button>
              <button
                className="rounded-md border border-amber-400 px-3 py-1 text-xs text-amber-200"
                onClick={() => resolveConflict(note.id, 'local')}
              >
                Keep my changes
              </button>
            </div>
          </div>
        )}
      </div>
      <div className="flex flex-1 flex-col overflow-y-auto px-6 py-8">
        <div className="flex flex-col gap-6 lg:flex-row">
          <div className="flex-1">
            <div className="rounded-xl border border-slate-800 bg-slate-900/70 p-6 shadow-lg">
              <EditorContent editor={editor} className="prose prose-invert max-w-none" />
            </div>
          </div>
          <div className="w-full max-w-sm space-y-4">
            <AttachmentPanel />
            <AudioRecorder
              onSave={async (blob) => {
                if (!note.id) return;
                try {
                  await uploadAttachment(note.id, new File([blob], 'recording.webm', { type: 'audio/webm' }));
                  toast.success('Recording saved as attachment');
                } catch (error) {
                  console.error(error);
                  toast.error('Failed to save recording');
                }
              }}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

export default NoteEditor;
