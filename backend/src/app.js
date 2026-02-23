import express from "express";
import cors from "cors";
import assistantRoutes from "./routes/assistant.routes.js";

const app = express();

app.use(cors());
app.use(express.json());

// Routes
app.use("/assistant", assistantRoutes);

export default app;
