import { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';

interface AudioRecorderProps {
  onSave: (blob: Blob) => void;
}

const AudioRecorder = ({ onSave }: AudioRecorderProps) => {
  const [recording, setRecording] = useState(false);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  useEffect(() => {
    return () => {
      recorderRef.current?.stream.getTracks().forEach((track) => track.stop());
    };
  }, []);

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      recorderRef.current = recorder;
      chunksRef.current = [];
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data);
        }
      };
      recorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
        setAudioUrl(URL.createObjectURL(blob));
        onSave(blob);
      };
      recorder.start();
      setRecording(true);
    } catch (error) {
      console.error(error);
      toast.error('Unable to access microphone');
    }
  };

  const stopRecording = () => {
    recorderRef.current?.stop();
    setRecording(false);
  };

  return (
    <div className="mt-6 rounded-lg border border-slate-800 bg-slate-900/60 p-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-slate-200">Audio Recorder</h3>
        {recording ? (
          <button className="rounded-md bg-red-500 px-3 py-1 text-xs" onClick={stopRecording}>
            Stop
          </button>
        ) : (
          <button className="rounded-md bg-cyberpunk px-3 py-1 text-xs text-slate-950" onClick={startRecording}>
            Record
          </button>
        )}
      </div>
      {audioUrl && (
        <audio controls src={audioUrl} className="mt-4 w-full" />
      )}
    </div>
  );
};

export default AudioRecorder;
