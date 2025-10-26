import { useEffect, useMemo, useState } from 'react';
import { useGroupsStore } from '../../store/groups';
import { useAuthStore } from '../../store/auth';
import { toast } from 'sonner';

interface GroupSidebarProps {
  activeGroupId?: string;
  onSelectGroup: (groupId: string) => Promise<void> | void;
}

const GroupSidebar = ({ activeGroupId, onSelectGroup }: GroupSidebarProps) => {
  const { groups, createGroup } = useGroupsStore();
  const { logout, user } = useAuthStore();
  const [showForm, setShowForm] = useState(false);
  const [groupName, setGroupName] = useState('');

  useEffect(() => {
    if (groups.length === 0) {
      setShowForm(true);
    }
  }, [groups]);

  const sortedGroups = useMemo(() => [...groups].sort((a, b) => a.position - b.position), [groups]);

  const onCreateGroup = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!groupName) return;
    try {
      const group = await createGroup({ name: groupName });
      setGroupName('');
      setShowForm(false);
      await onSelectGroup(group.id);
    } catch (error) {
      console.error(error);
      toast.error('Unable to create group');
    }
  };

  return (
    <aside className="flex w-72 flex-col border-r border-slate-800 bg-slate-950/80 p-4">
      <div className="mb-6">
        <h2 className="text-lg font-semibold text-cyberpunk">NotSphere</h2>
        <p className="mt-1 text-sm text-slate-300">Organize your notes in groups.</p>
        <button className="mt-3 text-sm text-cyberpunk underline" onClick={() => logout()}>
          Logout {user?.email}
        </button>
      </div>
      <div className="flex-1 space-y-2 overflow-y-auto">
        {sortedGroups.map((group) => (
          <button
            key={group.id}
            onClick={() => onSelectGroup(group.id)}
            className={`w-full rounded-md px-3 py-2 text-left transition hover:bg-slate-800 ${
              group.id === activeGroupId ? 'bg-slate-800 text-cyberpunk' : 'text-slate-200'
            }`}
          >
            <div className="flex items-center justify-between">
              <span>{group.name}</span>
              <span className="text-xs text-slate-400">#{group.position}</span>
            </div>
          </button>
        ))}
        {sortedGroups.length === 0 && (
          <p className="text-sm text-slate-400">
            Create your first group to start organizing your notes.
          </p>
        )}
      </div>
      <div className="mt-4 border-t border-slate-800 pt-4">
        {showForm ? (
          <form className="space-y-3" onSubmit={onCreateGroup}>
            <div>
              <label className="text-sm font-medium text-slate-300">Group name</label>
              <input
                className="mt-1 w-full rounded-md border border-slate-700 bg-slate-900 px-3 py-2"
                value={groupName}
                onChange={(event) => setGroupName(event.target.value)}
                required
              />
            </div>
            <div className="flex items-center gap-2">
              <button className="flex-1 rounded-md bg-cyberpunk px-4 py-2 font-medium text-slate-950">
                Save
              </button>
              <button
                type="button"
                className="rounded-md border border-slate-700 px-3 py-2 text-sm"
                onClick={() => setShowForm(false)}
              >
                Cancel
              </button>
            </div>
          </form>
        ) : (
          <button
            className="w-full rounded-md border border-dashed border-slate-700 px-3 py-2 text-sm text-slate-300"
            onClick={() => setShowForm(true)}
          >
            + New group
          </button>
        )}
      </div>
    </aside>
  );
};

export default GroupSidebar;
