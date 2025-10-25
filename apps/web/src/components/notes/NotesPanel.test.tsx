import { render, screen } from '@testing-library/react';
import { vi } from 'vitest';
import type { Mock } from 'vitest';
import NotesPanel from './NotesPanel';
import { useNotesStore } from '../../store/notes';
import { useAttachmentsStore } from '../../store/attachments';
import { Note } from '../../lib/types';

vi.mock('../../store/notes');
vi.mock('../../store/attachments');

const mockUseNotesStore = useNotesStore as unknown as Mock;
const mockUseAttachmentsStore = useAttachmentsStore as unknown as Mock;

const createNote = (overrides: Partial<Note> = {}): Note => ({
  id: 'note-1',
  groupId: 'group-1',
  title: 'Test Note',
  content: {},
  plainPreview: 'Preview',
  isPinned: false,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  deletedAt: null,
  ...overrides
});

describe('NotesPanel', () => {
  beforeEach(() => {
    (mockUseNotesStore as Mock).mockReturnValue({
      activeNoteId: 'note-1',
      setActiveNote: vi.fn(),
      fetchNote: vi.fn().mockResolvedValue(createNote())
    });
    (mockUseAttachmentsStore as Mock).mockReturnValue({
      setAttachments: vi.fn()
    });
  });

  afterEach(() => {
    (mockUseNotesStore as Mock).mockReset();
    (mockUseAttachmentsStore as Mock).mockReset();
    vi.clearAllMocks();
  });

  it('renders notes', () => {
    const notes = [createNote(), createNote({ id: 'note-2', title: 'Another Note' })];
    render(<NotesPanel notes={notes} />);
    expect(screen.getByText('Test Note')).toBeInTheDocument();
    expect(screen.getByText('Another Note')).toBeInTheDocument();
  });
});
