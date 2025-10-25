import { create } from 'zustand';
import api from '../lib/api';
import { Group } from '../lib/types';

interface GroupsState {
  groups: Group[];
  loading: boolean;
  fetchGroups: () => Promise<void>;
  createGroup: (payload: { name: string; color?: string }) => Promise<Group>;
  updateGroup: (id: string, payload: Partial<Group>) => Promise<Group>;
  deleteGroup: (id: string) => Promise<void>;
}

export const useGroupsStore = create<GroupsState>((set, get) => ({
  groups: [],
  loading: false,
  fetchGroups: async () => {
    set({ loading: true });
    const data = await api<{ groups: Group[] }>('/api/v1/groups');
    set({ groups: data.groups, loading: false });
  },
  createGroup: async (payload) => {
    const data = await api<{ group: Group }>('/api/v1/groups', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
    set({ groups: [...get().groups, data.group] });
    return data.group;
  },
  updateGroup: async (id, payload) => {
    const data = await api<{ group: Group }>(`/api/v1/groups/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload)
    });
    set({ groups: get().groups.map((group) => (group.id === id ? data.group : group)) });
    return data.group;
  },
  deleteGroup: async (id) => {
    await api(`/api/v1/groups/${id}`, { method: 'DELETE' });
    set({ groups: get().groups.filter((group) => group.id !== id) });
  }
}));
