import { useEffect, useMemo, useState } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Underline from '@tiptap/extension-underline';
import Highlight from '@tiptap/extension-highlight';
import Link from '@tiptap/extension-link';
import TaskList from '@tiptap/extension-task-list';
import TaskItem from '@tiptap/extension-task-item';
import { useNotesStore } from '../../store/notes';
import { useEditorStore } from '../../store/editor';
import debounce from '../../lib/debounce';
import { toast } from 'sonner';
import AttachmentPanel from '../attachments/AttachmentPanel';
import AudioRecorder from '../recorder/AudioRecorder';
import { useAttachmentsStore } from '../../store/attachments';

const NoteEditor = () => {
  const { activeNoteId, notes, updateNote } = useNotesStore();
  const { setStatus } = useEditorStore();
  const { uploadAttachment, setAttachments } = useAttachmentsStore();
  const [title, setTitle] = useState('');

  const note = useMemo(() => notes.find((n) => n.id === activeNoteId) ?? null, [notes, activeNoteId]);

  const editor = useEditor({
    extensions: [StarterKit, Underline, Highlight, Link.configure({ openOnClick: false }), TaskList, TaskItem],
    content: note?.content ?? '<p>Select a note to start writing</p>'
  });

  useEffect(() => {
    if (note && editor) {
      editor.commands.setContent(note.content || '<p></p>', false);
      setTitle(note.title || '');
      setAttachments(note.id, note.attachments ?? []);
    }
  }, [note, editor, setAttachments]);

  useEffect(() => {
    if (!editor) return;
    const handler = debounce(async ({ editor: ed }) => {
      if (!note) return;
      try {
        setStatus('saving');
        await updateNote(note.id, {
          title,
          content: ed.getJSON(),
          plainPreview: ed.getText().slice(0, 200)
        });
        setStatus('saved');
      } catch (error) {
        console.error(error);
        toast.error('Failed to save note');
        setStatus('offline');
      }
    }, 1000);

    editor.on('update', handler);
    return () => {
      editor.off('update', handler);
    };
  }, [editor, note, updateNote, setStatus, title]);

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
        <input
          className="w-full border-none bg-transparent text-2xl font-semibold text-white outline-none"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder="Untitled"
          onBlur={() => {
            if (note && title !== note.title) {
              updateNote(note.id, { title }).catch((error) => {
                console.error(error);
                toast.error('Failed to update title');
              });
            }
          }}
        />
      </div>
      <div className="flex flex-1 flex-col overflow-y-auto px-6 py-8">
        <div className="flex flex-col gap-6 lg:flex-row">
          <div className="flex-1">
            <div className="rounded-xl border border-slate-800 bg-slate-900/70 p-6 shadow-lg">
              <EditorContent editor={editor} className="prose prose-invert max-w-none" />
            </div>
          </div>
          <div className="w-full max-w-sm">
            <AttachmentPanel />
            <AudioRecorder
              onSave={async (blob) => {
                if (!activeNoteId) return;
                try {
                  await uploadAttachment(activeNoteId, new File([blob], 'recording.webm', { type: 'audio/webm' }));
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
