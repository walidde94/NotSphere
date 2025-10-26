import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../lib/prisma';
import { clearAuthCookies, createSession, createUser, setAuthCookies, verifyPassword } from './service';

const router = Router();

router.post('/register', async (req, res) => {
  const bodySchema = z.object({
    email: z.string().email(),
    password: z.string().min(8),
    name: z.string().min(1)
  });
  const body = bodySchema.parse(req.body);

  const user = await createUser(body.email, body.password, body.name);
  const tokens = await createSession(user.id, req.headers['user-agent']);
  setAuthCookies(res, tokens);

  res.status(201).json({ user: { id: user.id, email: user.email, name: user.name } });
});

router.post('/login', async (req, res) => {
  const bodySchema = z.object({ email: z.string().email(), password: z.string().min(8) });
  const body = bodySchema.parse(req.body);

  const user = await prisma.user.findUnique({ where: { email: body.email } });
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const valid = await verifyPassword(user.id, body.password);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const tokens = await createSession(user.id, req.headers['user-agent']);
  setAuthCookies(res, tokens);

  res.json({ user: { id: user.id, email: user.email, name: user.name } });
});

router.post('/logout', async (req, res) => {
  const refreshToken = req.cookies['notsphere_refresh'];
  if (refreshToken) {
    await prisma.session.deleteMany({ where: { refreshToken } });
  }
  clearAuthCookies(res);
  res.status(204).send();
});

router.get('/me', async (req, res) => {
  if (!req.user) {
    return res.status(401).json({ user: null });
  }
  const { id, email, name, avatarUrl } = req.user;
  res.json({ user: { id, email, name, avatarUrl } });
});

export default router;
