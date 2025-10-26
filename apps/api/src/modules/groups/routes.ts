import { Router } from 'express';
import { z } from 'zod';
import sanitizeHtml from 'sanitize-html';
import prisma from '../../lib/prisma';
import { requireAuth } from '../../middleware/requireAuth';

const scrubAttachment = <T extends { storageKey?: string }>(attachment: T) => {
  const { storageKey: _storageKey, ...rest } = attachment;
  return rest;
};

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
  const querySchema = z.object({
    query: z.string().optional(),
    page: z.coerce.number().int().positive().optional().default(1),
    limit: z.coerce.number().int().min(1).max(100).optional().default(20)
  });

  const { groupId } = paramsSchema.parse(req.params);
  const { query, page, limit } = querySchema.parse(req.query);

  const group = await prisma.group.findFirst({ where: { id: groupId, userId: req.user!.id } });
  if (!group) {
    return res.status(404).json({ error: 'Group not found' });
  }

  const where = {
    groupId,
    deletedAt: null,
    ...(query
      ? {
          OR: [
            { title: { contains: query, mode: 'insensitive' } },
            { plainPreview: { contains: query, mode: 'insensitive' } }
          ]
        }
      : {})
  } as const;

  const [notes, total] = await Promise.all([
    prisma.note.findMany({
      where,
      include: { attachments: true },
      orderBy: { updatedAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit
    }),
    prisma.note.count({ where })
  ]);

  res.json({
    notes: notes.map((note) => ({
      ...note,
      attachments: note.attachments.map((attachment) => scrubAttachment(attachment))
    })),
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit)
    }
  });
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
      title: body.title ? sanitizeHtml(body.title, { allowedTags: [], allowedAttributes: {} }) : 'Untitled note',
      content: body.content ?? { type: 'doc', content: [] },
      plainPreview: body.title
        ? sanitizeHtml(body.title, { allowedTags: [], allowedAttributes: {} })
        : '',
      isPinned: false
    },
    include: { attachments: true }
  });
  res.status(201).json({
    note: {
      ...note,
      attachments: note.attachments.map((attachment) => scrubAttachment(attachment))
    }
  });
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
