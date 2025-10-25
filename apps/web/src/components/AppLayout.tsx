import { ReactNode } from 'react';
import ThemeProvider from './ThemeProvider';

interface AppLayoutProps {
  children: ReactNode;
}

const AppLayout = ({ children }: AppLayoutProps) => {
  return (
    <ThemeProvider>
      <div className="flex min-h-screen w-full bg-slate-950 text-white">
        {children}
      </div>
    </ThemeProvider>
  );
};

export default AppLayout;
