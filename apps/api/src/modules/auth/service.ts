import { randomUUID } from 'crypto';
import argon2 from 'argon2';
import jwt from 'jsonwebtoken';
import { Request } from 'express';
import prisma from '../../lib/prisma';
import { loadEnv } from '../../config/env';

const env = loadEnv();

const ACCESS_COOKIE = 'notsphere_access';
const REFRESH_COOKIE = 'notsphere_refresh';

export const createUser = async (email: string, password: string, name: string) => {
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new Error('Email already registered');
  }

  const passwordHash = await argon2.hash(password);
  const user = await prisma.user.create({
    data: {
      email,
      name,
      passwordHash,
      provider: 'email'
    }
  });

  await prisma.$transaction(async (tx) => {
    const group = await tx.group.create({
      data: {
        userId: user.id,
        name: 'Getting Started',
        color: '#7F5AF0',
        position: 1
      }
    });

    await tx.note.create({
      data: {
        groupId: group.id,
        title: 'Welcome to NotSphere',
        plainPreview: 'Meet your new collaborative notebook.',
        content: {
          type: 'doc',
          content: [
            {
              type: 'heading',
              attrs: { level: 2 },
              content: [{ type: 'text', text: 'Welcome to NotSphere!' }]
            },
            {
              type: 'paragraph',
              content: [
                {
                  type: 'text',
                  text: 'Start capturing ideas, collaborate in real-time and work offline. Use the sidebar to create more groups.'
                }
              ]
            }
          ]
        }
      }
    });
  });

  return user;
};

export const createSession = async (userId: string, userAgent: string | undefined) => {
  const refreshToken = randomUUID();
  const session = await prisma.session.create({
    data: {
      userId,
      refreshToken,
      userAgent,
      expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30)
    }
  });

  const accessToken = jwt.sign({ sub: userId }, env.JWT_SECRET, { expiresIn: '15m' });

  return { session, accessToken, refreshToken };
};

export const verifyPassword = async (userId: string, password: string) => {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user?.passwordHash) return false;
  return argon2.verify(user.passwordHash, password);
};

export const getUserFromRequest = async (req: Request) => {
  const accessToken = req.cookies[ACCESS_COOKIE];
  const refreshToken = req.cookies[REFRESH_COOKIE];
  if (!accessToken || !refreshToken) return null;

  try {
    const payload = jwt.verify(accessToken, env.JWT_SECRET) as { sub: string };
    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    return user;
  } catch (error) {
    const session = await prisma.session.findFirst({ where: { refreshToken } });
    if (!session) return null;
    if (session.expiresAt < new Date()) {
      await prisma.session.delete({ where: { id: session.id } });
      return null;
    }
    const access = jwt.sign({ sub: session.userId }, env.JWT_SECRET, { expiresIn: '15m' });
    req.res?.cookie(ACCESS_COOKIE, access, {
      httpOnly: true,
      sameSite: 'lax',
      secure: env.NODE_ENV === 'production',
      maxAge: 1000 * 60 * 15
    });
    const user = await prisma.user.findUnique({ where: { id: session.userId } });
    return user;
  }
};

export const setAuthCookies = (
  res: import('express').Response,
  tokens: { accessToken: string; refreshToken: string }
) => {
  res.cookie(ACCESS_COOKIE, tokens.accessToken, {
    httpOnly: true,
    sameSite: 'lax',
    secure: env.NODE_ENV === 'production',
    maxAge: 1000 * 60 * 15
  });
  res.cookie(REFRESH_COOKIE, tokens.refreshToken, {
    httpOnly: true,
    sameSite: 'lax',
    secure: env.NODE_ENV === 'production',
    maxAge: 1000 * 60 * 60 * 24 * 30
  });
};

export const clearAuthCookies = (res: import('express').Response) => {
  res.clearCookie(ACCESS_COOKIE);
  res.clearCookie(REFRESH_COOKIE);
};
