import type { Config } from 'tailwindcss';
import { fontFamily } from 'tailwindcss/defaultTheme';

const config: Config = {
  darkMode: ['class'],
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', ...fontFamily.sans]
      },
      colors: {
        cyberpunk: {
          DEFAULT: '#7F5AF0',
          foreground: '#0F0E17'
        }
      }
    }
  },
  plugins: []
};

export default config;
