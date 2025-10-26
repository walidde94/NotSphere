import { useEffect } from 'react';
import { toast } from 'sonner';
import { useNotesStore } from '../store/notes';

export const useOfflineSync = () => {
  const syncPending = useNotesStore((state) => state.syncPending);

  useEffect(() => {
    syncPending().catch((error) => console.error('Initial pending sync failed', error));
  }, [syncPending]);

  useEffect(() => {
    const handleOnline = () => {
      toast.success('Back online. Syncing notes…');
      syncPending().catch((error) => console.error('Failed to sync after reconnect', error));
    };
    window.addEventListener('online', handleOnline);
    return () => window.removeEventListener('online', handleOnline);
  }, [syncPending]);
};
