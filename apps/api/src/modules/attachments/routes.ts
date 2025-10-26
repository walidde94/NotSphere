import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import prisma from '../../lib/prisma';
import { requireAuth } from '../../middleware/requireAuth';
import { deleteFromBucket, uploadToBucket } from '../../lib/storage';
import logger from '../../config/logger';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

router.use(requireAuth);

router.post('/notes/:noteId/attachments', upload.single('file'), async (req, res) => {
  const paramsSchema = z.object({ noteId: z.string().cuid() });
  const { noteId } = paramsSchema.parse(req.params);

  if (!req.file) {
    return res.status(400).json({ error: 'File is required' });
  }

  const note = await prisma.note.findFirst({ where: { id: noteId, group: { userId: req.user!.id } } });
  if (!note) {
    return res.status(404).json({ error: 'Note not found' });
  }

  const { key, url } = await uploadToBucket({
    buffer: req.file.buffer,
    mimetype: req.file.mimetype,
    filename: req.file.originalname
  });

  const type: 'image' | 'audio' | 'file' = req.file.mimetype.startsWith('image')
    ? 'image'
    : req.file.mimetype.startsWith('audio')
    ? 'audio'
    : 'file';

  const attachment = await prisma.attachment.create({
    data: {
      noteId,
      filename: req.file.originalname,
      url,
      storageKey: key,
      size: req.file.size,
      type
    }
  });

  const { storageKey: _storageKey, ...safeAttachment } = attachment;
  res.status(201).json({ attachment: safeAttachment });
});

router.delete('/attachments/:id', async (req, res) => {
  const paramsSchema = z.object({ id: z.string().cuid() });
  const { id } = paramsSchema.parse(req.params);
  const attachment = await prisma.attachment.findUnique({
    where: { id },
    include: { note: { include: { group: true } } }
  });
  if (!attachment || attachment.note.group.userId !== req.user!.id) {
    return res.status(404).json({ error: 'Attachment not found' });
  }
  await prisma.attachment.delete({ where: { id } });
  try {
    await deleteFromBucket(attachment.storageKey);
  } catch (error) {
    logger.warn({ err: error, attachmentId: id }, 'Failed to delete attachment object from storage');
  }
  res.status(204).send();
});

export default router;
