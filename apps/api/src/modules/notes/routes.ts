import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../lib/prisma';
import { requireAuth } from '../../middleware/requireAuth';

const router = Router();

router.use(requireAuth);

router.get('/:id', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const { id } = paramsSchema.parse(req.params);
  const note = await prisma.note.findFirst({
    where: { id, group: { userId: req.user!.id } },
    include: { attachments: true }
  });
  if (!note) {
    return res.status(404).json({ error: 'Note not found' });
  }
  res.json({ note });
});

router.patch('/:id', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const bodySchema = z.object({
    title: z.string().optional(),
    content: z.any().optional(),
    isPinned: z.boolean().optional(),
    plainPreview: z.string().optional()
  });
  const { id } = paramsSchema.parse(req.params);
  const body = bodySchema.parse(req.body);

  const existing = await prisma.note.findFirst({ where: { id, group: { userId: req.user!.id } } });
  if (!existing) {
    return res.status(404).json({ error: 'Note not found' });
  }

  const note = await prisma.note.update({
    where: { id },
    data: {
      ...body,
      updatedAt: new Date()
    }
  });
  res.json({ note });
});

router.delete('/:id', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const { id } = paramsSchema.parse(req.params);
  const existing = await prisma.note.findFirst({ where: { id, group: { userId: req.user!.id } } });
  if (!existing) {
    return res.status(404).json({ error: 'Note not found' });
  }
  await prisma.note.update({
    where: { id },
    data: { deletedAt: new Date() }
  });
  res.status(204).send();
});

router.post('/:id/restore', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const { id } = paramsSchema.parse(req.params);
  const existing = await prisma.note.findFirst({ where: { id, group: { userId: req.user!.id } } });
  if (!existing) {
    return res.status(404).json({ error: 'Note not found' });
  }
  const note = await prisma.note.update({
    where: { id },
    data: { deletedAt: null }
  });
  res.json({ note });
});

export default router;
