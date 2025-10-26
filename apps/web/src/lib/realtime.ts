import { io } from 'socket.io-client';

export const notesSocket = io('/notes', {
  withCredentials: true,
  transports: ['websocket'],
  autoConnect: true
});
