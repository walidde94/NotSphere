import prisma from '../../../lib/prisma';
import { createUser } from '../service';

jest.mock('../../../lib/prisma', () => ({
  __esModule: true,
  default: {
    user: {
      findUnique: jest.fn(),
      create: jest.fn()
    }
  }
}));

describe('createUser', () => {
  it('throws when email is taken', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValueOnce({ id: '1' });
    await expect(createUser('test@example.com', 'password123', 'Test User')).rejects.toThrow(
      'Email already registered'
    );
  });

  it('creates user when email is available', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValueOnce(null);
    (prisma.user.create as jest.Mock).mockResolvedValueOnce({ id: '1', email: 'test@example.com' });
    const user = await createUser('test@example.com', 'password123', 'Test User');
    expect(user).toEqual({ id: '1', email: 'test@example.com' });
  });
});
