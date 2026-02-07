import fetch from "node-fetch";
import dotenv from "dotenv";
dotenv.config();

let chatHistory = [];

export async function askAI(text) {
  const systemPrompt = {
    role: "system",
    content: `You are VisionMate, a professional voice assistant for visually impaired users.
    - Always reply in English.
    - Keep responses brief, helpful, and polite.
    - Today is ${new Date().toDateString()}.`
  };

  chatHistory.push({ role: "user", content: text });
  
  // Keep last 10 messages for context
  if (chatHistory.length > 10) chatHistory.shift();

  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [systemPrompt, ...chatHistory],
        max_tokens: 150
      })
    });

    const data = await response.json();
    if (!data.choices || data.choices.length === 0) throw new Error("No response from AI");
    
    const reply = data.choices[0].message.content;
    chatHistory.push({ role: "assistant", content: reply });
    return reply;
  } catch (error) {
    console.error("OpenAI Error:", error);
    throw error;
  }
}
