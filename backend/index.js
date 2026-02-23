import app from "./src/app.js";
import { config } from "./src/config/env.js";

const PORT = config.port || 3000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Backend running on http://0.0.0.0:${PORT}`);
});
