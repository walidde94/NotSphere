export interface Group {
  id: string;
  name: string;
  color: string;
  position: number;
  createdAt: string;
  updatedAt: string;
}

export interface Note {
  id: string;
  groupId: string;
  title: string;
  content: any;
  plainPreview: string;
  isPinned: boolean;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string | null;
  attachments?: Attachment[];
}

export interface Attachment {
  id: string;
  noteId: string;
  type: 'image' | 'audio' | 'file';
  filename: string;
  url: string;
  size: number;
  createdAt: string;
}
