/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["'DM Sans'", "system-ui", "sans-serif"],
        mono: ["'JetBrains Mono'", "monospace"],
      },
      colors: {
        brand: {
          50:  "#f0f4ff",
          100: "#dce7ff",
          500: "#4f6ef7",
          600: "#3d5cf5",
          700: "#2d4ae3",
          900: "#1a2d8f",
        },
      },
    },
  },
  plugins: [],
};
