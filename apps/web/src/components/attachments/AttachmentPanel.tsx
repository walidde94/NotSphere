import { useRef } from 'react';
import { useAttachmentsStore } from '../../store/attachments';
import { useNotesStore } from '../../store/notes';
import { toast } from 'sonner';

const AttachmentPanel = () => {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const { activeNoteId } = useNotesStore();
  const { attachments, uploadAttachment, deleteAttachment } = useAttachmentsStore();

  const noteAttachments = activeNoteId ? attachments[activeNoteId] ?? [] : [];

  const handleUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    if (!activeNoteId || !event.target.files?.[0]) return;
    const file = event.target.files[0];
    try {
      await uploadAttachment(activeNoteId, file);
      toast.success('Attachment uploaded');
    } catch (error) {
      console.error(error);
      toast.error('Upload failed');
    }
  };

  return (
    <div className="mt-6 rounded-lg border border-slate-800 bg-slate-900/60 p-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-slate-200">Attachments</h3>
        <button
          className="text-xs text-cyberpunk"
          onClick={() => fileInputRef.current?.click()}
          disabled={!activeNoteId}
        >
          Upload
        </button>
        <input
          ref={fileInputRef}
          type="file"
          className="hidden"
          onChange={handleUpload}
        />
      </div>
      <div className="mt-3 space-y-2">
        {noteAttachments.map((attachment) => (
          <div
            key={attachment.id}
            className="flex items-center justify-between rounded-md border border-slate-800 bg-slate-950 px-3 py-2 text-sm"
          >
            <span>{attachment.filename}</span>
            <button
              className="text-xs text-red-400"
              onClick={async () => {
                try {
                  await deleteAttachment(attachment.id, attachment.noteId);
                  toast.success('Attachment removed');
                } catch (error) {
                  console.error(error);
                  toast.error('Failed to remove attachment');
                }
              }}
            >
              Remove
            </button>
          </div>
        ))}
        {noteAttachments.length === 0 && (
          <p className="text-xs text-slate-500">No attachments yet.</p>
        )}
      </div>
    </div>
  );
};

export default AttachmentPanel;
