import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/auth';
import { toast } from 'sonner';

const AuthPage = () => {
  const navigate = useNavigate();
  const { register, login } = useAuthStore();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [form, setForm] = useState({ email: '', password: '', name: '' });

  useEffect(() => {
    fetch('/api/v1/auth/me', { credentials: 'include' }).catch(() => {});
  }, []);

  const onSubmit = async (event: React.FormEvent) => {
    event.preventDefault();

    try {
      if (mode === 'login') {
        await login(form.email, form.password);
      } else {
        await register(form.email, form.password, form.name);
      }
      toast.success('Welcome to NotSphere!');
      navigate('/');
    } catch (error) {
      console.error(error);
      toast.error('Authentication failed.');
    }
  };

  return (
    <div className="flex h-full w-full items-center justify-center bg-slate-950 text-white">
      <div className="w-full max-w-md rounded-xl bg-slate-900 p-8 shadow-lg">
        <h1 className="text-2xl font-semibold text-cyberpunk">{mode === 'login' ? 'Login' : 'Create account'}</h1>
        <p className="mt-2 text-sm text-slate-300">
          {mode === 'login'
            ? 'Use your email and password to continue.'
            : 'Create your NotSphere account to start capturing ideas.'}
        </p>
        <form className="mt-6 space-y-4" onSubmit={onSubmit}>
          {mode === 'register' && (
            <div>
              <label className="block text-sm font-medium">Name</label>
              <input
                className="mt-1 w-full rounded border border-slate-700 bg-slate-950 p-2"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                required
              />
            </div>
          )}
          <div>
            <label className="block text-sm font-medium">Email</label>
            <input
              className="mt-1 w-full rounded border border-slate-700 bg-slate-950 p-2"
              type="email"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium">Password</label>
            <input
              className="mt-1 w-full rounded border border-slate-700 bg-slate-950 p-2"
              type="password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              required
            />
          </div>
          <button
            type="submit"
            className="w-full rounded bg-cyberpunk px-4 py-2 font-semibold text-slate-950"
          >
            {mode === 'login' ? 'Sign in' : 'Create account'}
          </button>
        </form>
        <button
          className="mt-4 text-sm text-cyberpunk underline"
          onClick={() => setMode(mode === 'login' ? 'register' : 'login')}
        >
          {mode === 'login' ? 'Create an account' : 'Already have an account? Sign in'}
        </button>
      </div>
    </div>
  );
};

export default AuthPage;
