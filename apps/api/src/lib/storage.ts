import { S3Client, PutObjectCommand, DeleteObjectCommand, HeadBucketCommand, CreateBucketCommand } from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';
import { loadEnv } from '../config/env';

const env = loadEnv();

const useSSL = env.MINIO_USE_SSL === 'true' || env.MINIO_USE_SSL === '1';

export const s3 = new S3Client({
  region: env.MINIO_REGION,
  forcePathStyle: true,
  endpoint: `${useSSL ? 'https' : 'http'}://${env.MINIO_ENDPOINT}:${env.MINIO_PORT}`,
  credentials: {
    accessKeyId: env.MINIO_ACCESS_KEY,
    secretAccessKey: env.MINIO_SECRET_KEY
  }
});

let bucketEnsured = false;

export const ensureBucket = async () => {
  if (bucketEnsured) return;
  try {
    await s3.send(new HeadBucketCommand({ Bucket: env.MINIO_BUCKET }));
    bucketEnsured = true;
  } catch (error) {
    const status = (error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
    if (status === 404) {
      try {
        await s3.send(new CreateBucketCommand({ Bucket: env.MINIO_BUCKET }));
        bucketEnsured = true;
      } catch (createError) {
        const createStatus = (createError as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
        if (createStatus && createStatus >= 200 && createStatus < 300) {
          bucketEnsured = true;
          return;
        }
        if ((createError as Error).name !== 'BucketAlreadyOwnedByYou') {
          throw createError;
        }
        bucketEnsured = true;
        return;
      }
    } else if ((error as Error).name !== 'NotFound') {
      throw error;
    }
  }
};

export const uploadToBucket = async (options: { buffer: Buffer; mimetype: string; filename: string }) => {
  await ensureBucket();
  const key = `${randomUUID()}-${options.filename}`;
  await s3.send(
    new PutObjectCommand({
      Bucket: env.MINIO_BUCKET,
      Key: key,
      Body: options.buffer,
      ContentType: options.mimetype,
      ACL: 'private'
    })
  );

  return { key, url: `${env.PUBLIC_S3_URL}/${key}` };
};

export const deleteFromBucket = async (key: string) => {
  await ensureBucket();
  await s3.send(
    new DeleteObjectCommand({
      Bucket: env.MINIO_BUCKET,
      Key: key
    })
  );
};
