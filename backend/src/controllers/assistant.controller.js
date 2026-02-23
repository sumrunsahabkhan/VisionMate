import { askAI } from "../services/openai.service.js";
import { getNews } from "../services/news.service.js";
import { getWeather } from "../services/weather.service.js";
import { speakPolly } from "../services/polly.service.js";

export const handleAssistantRequest = async (req, res) => {
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
};
