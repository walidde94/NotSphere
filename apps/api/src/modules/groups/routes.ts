import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../lib/prisma';
import { requireAuth } from '../../middleware/requireAuth';

const router = Router();

router.use(requireAuth);

router.get('/', async (req, res) => {
  const groups = await prisma.group.findMany({
    where: { userId: req.user!.id },
    orderBy: { position: 'asc' }
  });
  res.json({ groups });
});

router.post('/', async (req, res) => {
  const bodySchema = z.object({ name: z.string().min(1), color: z.string().optional() });
  const body = bodySchema.parse(req.body);
  const position = (await prisma.group.count({ where: { userId: req.user!.id } })) + 1;
  const group = await prisma.group.create({
    data: {
      userId: req.user!.id,
      name: body.name,
      color: body.color ?? '#7F5AF0',
      position
    }
  });
  res.status(201).json({ group });
});

router.get('/:groupId/notes', async (req, res) => {
  const paramsSchema = z.object({ groupId: z.string().cuid() });
  const { groupId } = paramsSchema.parse(req.params);

  const notes = await prisma.note.findMany({
    where: { groupId, deletedAt: null },
    orderBy: { updatedAt: 'desc' }
  });
  res.json({ notes });
});

router.post('/:groupId/notes', async (req, res) => {
  const paramsSchema = z.object({ groupId: z.string().cuid() });
  const bodySchema = z.object({ title: z.string().optional(), content: z.any().optional() });
  const { groupId } = paramsSchema.parse(req.params);
  const body = bodySchema.parse(req.body);

  const group = await prisma.group.findFirst({ where: { id: groupId, userId: req.user!.id } });
  if (!group) {
    return res.status(404).json({ error: 'Group not found' });
  }

  const note = await prisma.note.create({
    data: {
      groupId,
      title: body.title ?? 'Untitled note',
      content: body.content ?? { type: 'doc', content: [] },
      plainPreview: '',
      isPinned: false
    }
  });
  res.status(201).json({ note });
});

router.patch('/:id', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const bodySchema = z.object({
    name: z.string().optional(),
    color: z.string().optional(),
    position: z.number().int().optional()
  });
  const { id } = paramsSchema.parse(req.params);
  const body = bodySchema.parse(req.body);

  const existing = await prisma.group.findFirst({ where: { id, userId: req.user!.id } });
  if (!existing) {
    return res.status(404).json({ error: 'Group not found' });
  }

  const group = await prisma.group.update({
    where: { id },
    data: body
  });
  res.json({ group });
});

router.delete('/:id', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const { id } = paramsSchema.parse(req.params);
  const existing = await prisma.group.findFirst({ where: { id, userId: req.user!.id } });
  if (!existing) {
    return res.status(404).json({ error: 'Group not found' });
  }
  await prisma.group.delete({ where: { id } });
  res.status(204).send();
});

export default router;
