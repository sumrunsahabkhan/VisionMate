import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { askAI } from "./openai.js";
import { getNews } from "./news.js";
import { getWeather } from "./weather.js";
import { speakPolly } from "./polly.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.post("/assistant", async (req, res) => {
  const { text, type, city, country } = req.body;
  const lowerText = (text || "").toLowerCase();
  
  console.log(`📡 Request: ${type} | Text: ${text}`);

  try {
    let reply;
    if (type === "news" || lowerText.includes("news")) {
      reply = await getNews(country || "us");
    } else if (type === "weather" || lowerText.includes("weather")) {
      reply = await getWeather(city || "London");
    } else {
      reply = await askAI(text);
    }

    console.log(`🤖 AI Reply: ${reply}`);

    try {
      const audioBuffer = await speakPolly(reply);
      res.set("Content-Type", "audio/mpeg");
      res.set("Access-Control-Expose-Headers", "X-Reply-Text");
      res.set("X-Reply-Text", encodeURIComponent(reply));
      return res.send(audioBuffer);
    } catch (pollyError) {
      console.error("❌ Polly Failed, sending text fallback");
      return res.status(200).json({ type: "text", text: reply });
    }

  } catch (e) {
    console.error("💥 Backend Error:", e.message);
    res.status(500).json({ error: true, message: "Server error" });
  }
});

const PORT = 3000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Backend running on http://0.0.0.0:${PORT}`);
});
