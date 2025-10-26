import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../lib/prisma';
import { requireAuth } from '../../middleware/requireAuth';

const router = Router();
router.use(requireAuth);

const bodySchema = z.object({ noteId: z.string().cuid() });

const buildHandler = (action: 'summarize' | 'grammar' | 'flashcards') =>
  async (req: import('express').Request, res: import('express').Response) => {
    const { noteId } = bodySchema.parse(req.body);
    const note = await prisma.note.findFirst({
      where: { id: noteId, group: { userId: req.user!.id } }
    });
    if (!note) {
      return res.status(404).json({ error: 'Note not found' });
    }

    const plain = typeof note.content === 'object' ? JSON.stringify(note.content) : String(note.content);
    const preview = plain.slice(0, 500);

    switch (action) {
      case 'summarize':
        return res.json({ result: `Summary (stub): ${preview}` });
      case 'grammar':
        return res.json({ result: `Grammar suggestions (stub): ${preview}` });
      case 'flashcards':
        return res.json({ result: [`Flashcard stub for ${note.title}`] });
      default:
        return res.json({ result: null });
    }
  };

router.post('/summarize', buildHandler('summarize'));
router.post('/grammar', buildHandler('grammar'));
router.post('/flashcards', buildHandler('flashcards'));

export default router;
