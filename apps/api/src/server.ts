import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import csrf from 'csurf';
import http from 'http';
import { Server } from 'socket.io';
import pinoHttp from 'pino-http';
import logger from './config/logger';
import { loadEnv } from './config/env';
import apiRoutes from './routes';
import prisma from './lib/prisma';
import { ensureBucket } from './lib/storage';
import { attachUser } from './middleware/attachUser';

const env = loadEnv();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: env.CLIENT_URL,
    credentials: true
  }
});

io.of('/notes').on('connection', (socket) => {
  socket.on('join', (room: string) => socket.join(room));
  socket.on('note:content', (data) => socket.to(data.noteId).emit('note:content', data));
  socket.on('note:meta', (data) => socket.to(data.noteId).emit('note:meta', data));
  socket.on('note:presence', (data) => socket.to(data.noteId).emit('note:presence', data));
});

const csrfProtection = csrf({
  cookie: { httpOnly: true, sameSite: 'lax', secure: env.NODE_ENV === 'production' },
  ignoreMethods: ['GET', 'HEAD', 'OPTIONS'],
  value: (req) => req.headers['x-csrf-token']?.toString() ?? (req.cookies['notsphere_csrf'] as string)
});

app.set('trust proxy', 1);
app.use(pinoHttp({ logger }));
app.use(helmet());
app.use(
  cors({
    origin: env.CLIENT_URL,
    credentials: true
  })
);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser(env.SESSION_SECRET));
app.use(
  rateLimit({
    windowMs: 60_000,
    limit: 100
  })
);

app.use(
  '/api/v1',
  attachUser,
  csrfProtection,
  (req, res, next) => {
    res.cookie('notsphere_csrf', req.csrfToken(), {
      httpOnly: false,
      sameSite: 'lax',
      secure: env.NODE_ENV === 'production'
    });
    next();
  },
  apiRoutes
);

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error({ err }, 'Unhandled error');
  res.status(err.status || 500).json({ error: 'Internal Server Error' });
});

const start = async () => {
  if (env.NODE_ENV !== 'test') {
    try {
      await ensureBucket();
    } catch (error) {
      logger.error({ err: error }, 'Failed to ensure object storage bucket');
      process.exit(1);
    }
  }

  const port = Number(env.PORT);
  server.listen(port, () => {
    logger.info(`API server listening on port ${port}`);
  });
};

start();

process.on('SIGINT', async () => {
  await prisma.$disconnect();
  process.exit(0);
});
