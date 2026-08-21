import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Served at host root — do NOT set `base`.
export default defineConfig({
  plugins: [react()],
});
