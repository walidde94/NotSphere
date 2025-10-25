import { NextFunction, Request, Response } from 'express';
import { getUserFromRequest } from '../modules/auth/service';

export const attachUser = async (req: Request, _res: Response, next: NextFunction) => {
  if (!req.user) {
    req.user = await getUserFromRequest(req) ?? undefined;
  }
  next();
};
