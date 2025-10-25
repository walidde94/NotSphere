import { create } from 'zustand';

export interface User {
  id: string;
  email: string;
  name: string;
  avatarUrl?: string | null;
}

interface AuthState {
  user: User | null;
  loading: boolean;
  register: (email: string, password: string, name: string) => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  fetchMe: () => Promise<void>;
}

const request = async (input: RequestInfo, init?: RequestInit) => {
  const response = await fetch(input, {
    ...init,
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers || {})
    }
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  return response.json();
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  loading: false,
  register: async (email, password, name) => {
    set({ loading: true });
    await request('/api/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email, password, name })
    });
    await useAuthStore.getState().fetchMe();
    set({ loading: false });
  },
  login: async (email, password) => {
    set({ loading: true });
    await request('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password })
    });
    await useAuthStore.getState().fetchMe();
    set({ loading: false });
  },
  logout: async () => {
    await request('/api/v1/auth/logout', { method: 'POST' });
    set({ user: null });
  },
  fetchMe: async () => {
    try {
      const data = await request('/api/v1/auth/me');
      set({ user: data.user, loading: false });
    } catch (error) {
      set({ user: null, loading: false });
    }
  }
}));
