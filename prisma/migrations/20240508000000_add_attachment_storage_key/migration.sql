ALTER TABLE "Attachment" ADD COLUMN "storageKey" TEXT;
UPDATE "Attachment" SET "storageKey" = 'legacy-' || "id" WHERE "storageKey" IS NULL;
ALTER TABLE "Attachment" ALTER COLUMN "storageKey" SET NOT NULL;
