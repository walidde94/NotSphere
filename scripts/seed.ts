import 'dotenv/config';
import prisma from '../apps/api/src/lib/prisma';
import { createUser, createSession } from '../apps/api/src/modules/auth/service';

const seed = async () => {
  const email = 'demo@notsphere.dev';
  const password = 'password123';
  const name = 'Demo User';

  try {
    const user = await createUser(email, password, name);
    await createSession(user.id, 'seed-script');
    const group = await prisma.group.create({
      data: {
        userId: user.id,
        name: 'Sample Group',
        color: '#7F5AF0',
        position: 1
      }
    });
    await prisma.note.create({
      data: {
        groupId: group.id,
        title: 'Welcome to NotSphere',
        plainPreview: 'Start capturing your ideas right away.',
        content: { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Start capturing your ideas right away.' }] }] }
      }
    });
    console.log('Seed completed');
  } catch (error) {
    if (error instanceof Error && error.message === 'Email already registered') {
      console.log('Seed data already exists');
      return;
    }
    console.error(error);
  } finally {
    await prisma.$disconnect();
  }
};

seed();
