import { NextFunction, Request, Response } from 'express';
import { getUserFromRequest } from '../modules/auth/service';

export const requireAuth = async (req: Request, res: Response, next: NextFunction) => {
  const user = await getUserFromRequest(req);
  if (!user) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  (req as Request & { user: typeof user }).user = user;
  return next();
};

export type AuthenticatedRequest = Request & { user: { id: string } };
