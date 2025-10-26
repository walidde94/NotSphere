import { Router } from 'express';
import authRoutes from '../modules/auth/routes';
import groupsRoutes from '../modules/groups/routes';
import notesRoutes from '../modules/notes/routes';
import attachmentsRoutes from '../modules/attachments/routes';
import aiRoutes from '../modules/ai/routes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/groups', groupsRoutes);
router.use('/notes', notesRoutes);
router.use('/', attachmentsRoutes);
router.use('/ai', aiRoutes);

export default router;
