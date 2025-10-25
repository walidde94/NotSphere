import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.string().default('3000'),
  DATABASE_URL: z.string(),
  SESSION_SECRET: z.string(),
  JWT_SECRET: z.string(),
  COOKIE_DOMAIN: z.string().optional(),
  CLIENT_URL: z.string().default('http://localhost:5173'),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  MINIO_ENDPOINT: z.string().default('localhost'),
  MINIO_PORT: z.string().default('9000'),
  MINIO_ACCESS_KEY: z.string().default('minioadmin'),
  MINIO_SECRET_KEY: z.string().default('minioadmin'),
  MINIO_BUCKET: z.string().default('notsphere'),
  CSRF_SECRET: z.string().default('csrf-secret')
});

type Env = z.infer<typeof envSchema>;

export const loadEnv = (): Env => {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    console.error('Invalid environment configuration', result.error.flatten().fieldErrors);
    process.exit(1);
  }
  return result.data;
};

export type { Env };
