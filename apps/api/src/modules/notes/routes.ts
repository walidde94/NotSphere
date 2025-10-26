import { Router } from 'express';
import { z } from 'zod';
import sanitizeHtml from 'sanitize-html';
import prisma from '../../lib/prisma';
import { requireAuth } from '../../middleware/requireAuth';

const router = Router();

router.use(requireAuth);

const sanitizeText = (value?: string | null) => {
  if (value === undefined || value === null) return undefined;
  return sanitizeHtml(value, { allowedTags: [], allowedAttributes: {} });
};

const scrubAttachment = <T extends { storageKey?: string }>(attachment: T) => {
  const { storageKey: _storageKey, ...rest } = attachment;
  return rest;
};

const scrubNote = (note: any) => ({
  ...note,
  attachments: Array.isArray(note.attachments)
    ? note.attachments.map((attachment: any) => scrubAttachment(attachment))
    : []
});

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
  res.json({ note: scrubNote(note) });
});

router.patch('/:id', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const bodySchema = z.object({
    title: z.string().optional(),
    content: z.any().optional(),
    isPinned: z.boolean().optional(),
    plainPreview: z.string().optional(),
    clientUpdatedAt: z.string().datetime().optional()
  });
  const { id } = paramsSchema.parse(req.params);
  const { clientUpdatedAt, ...body } = bodySchema.parse(req.body);

  const existing = await prisma.note.findFirst({
    where: { id, group: { userId: req.user!.id } },
    include: { attachments: true }
  });
  if (!existing) {
    return res.status(404).json({ error: 'Note not found' });
  }

  const cleanTitle = sanitizeText(body.title);
  const cleanPreview = sanitizeText(body.plainPreview);

  const updateData: Record<string, unknown> = {};
  if (cleanTitle !== undefined) updateData.title = cleanTitle;
  if (body.content !== undefined) updateData.content = body.content;
  if (body.isPinned !== undefined) updateData.isPinned = body.isPinned;
  if (cleanPreview !== undefined) updateData.plainPreview = cleanPreview;

  const conflict = clientUpdatedAt ? new Date(clientUpdatedAt) < existing.updatedAt : false;

  const note = await prisma.note.update({
    where: { id },
    data: updateData,
    include: { attachments: true }
  });

  res.json({
    note: scrubNote(note),
    conflict,
    previous: conflict ? scrubNote(existing) : undefined
  });
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
  const existing = await prisma.note.findFirst({
    where: { id, group: { userId: req.user!.id } },
    include: { attachments: true }
  });
  if (!existing) {
    return res.status(404).json({ error: 'Note not found' });
  }
  const note = await prisma.note.update({
    where: { id },
    data: { deletedAt: null },
    include: { attachments: true }
  });
  res.json({ note: scrubNote(note) });
});

export default router;
