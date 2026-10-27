/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        ibm: {
          blue: '#0f62fe',
          dark: '#161616',
          darker: '#0a0a0c',
          terminal: '#00ff66',
          amber: '#ffb000',
          cyber: '#00f0ff',
          alert: '#ff3366',
          card: 'rgba(22, 22, 26, 0.85)'
        }
      },
      fontFamily: {
        mono: ['"Share Tech Mono"', 'Consolas', 'Courier New', 'monospace'],
        sans: ['"Inter"', 'system-ui', 'sans-serif'],
      },
      animation: {
        'pulse-fast': 'pulse 1s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'glow': 'glow 2s ease-in-out infinite alternate',
      },
      keyframes: {
        glow: {
          '0%': { boxShadow: '0 0 5px rgba(0, 240, 255, 0.4), inset 0 0 5px rgba(0, 240, 255, 0.2)' },
          '100%': { boxShadow: '0 0 20px rgba(0, 240, 255, 0.8), inset 0 0 10px rgba(0, 240, 255, 0.4)' },
        }
      }
    },
  },
  plugins: [],
}
