import express from "express";
import { handleAssistantRequest } from "../controllers/assistant.controller.js";

const router = express.Router();

router.post("/", handleAssistantRequest);

export default router;
