import { ReactNode, useEffect, useState } from 'react';

type Theme = 'light' | 'dark' | 'cyberpunk';

const ThemeProvider = ({ children }: { children: ReactNode }) => {
  const [theme, setTheme] = useState<Theme>('cyberpunk');

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  return (
    <div className={`theme-${theme} min-h-screen w-full bg-slate-950 text-white`}>
      {children}
    </div>
  );
};

export default ThemeProvider;
