import path from "path"
import vue from "@vitejs/plugin-vue"

/* eslint-disable no-undef */
export default {
  plugins: [vue()],
  resolve: {      
    alias: {
      "@": path.resolve(__dirname, "src"),
      "bootstrap": path.resolve(__dirname, "node_modules/bootstrap")
    }
  }
}
