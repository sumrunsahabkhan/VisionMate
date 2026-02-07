import "dotenv/config";
import fetch from "node-fetch";
import { PollyClient, DescribeVoicesCommand } from "@aws-sdk/client-polly";

console.log("🔍 Checking Environment Variables...");
console.log({
  OPENAI: !!process.env.OPENAI_API_KEY,
  AWS: !!process.env.AWS_ACCESS_KEY_ID,
  WEATHER: !!process.env.WEATHER_API_KEY,
  NEWS: !!process.env.NEWS_API_KEY,
});

async function testOpenAI() {
  console.log("\n🔹 1) Testing OpenAI...");
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: "Say hello" }],
      })
    });
    const data = await res.json();
    if (data.choices) {
      console.log("✅ OpenAI WORKS:", data.choices[0].message.content);
    } else {
      console.error("❌ OpenAI ERROR:", data.error?.message || "Unknown error");
    }
  } catch (err) {
    console.error("❌ OpenAI ERROR:", err.message);
  }
}

async function testPolly() {
  console.log("\n🔹 2) Testing Amazon Polly...");
  const client = new PollyClient({
    region: process.env.AWS_REGION || "us-east-1",
    credentials: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    }
  });

  try {
    const command = new DescribeVoicesCommand({});
    const data = await client.send(command);
    console.log("✅ Polly WORKS. Voices:", data.Voices.length);
  } catch (err) {
    console.error("❌ Polly ERROR:", err.message);
  }
}

async function testWeather() {
  console.log("\n🔹 3) Testing Weather API...");
  try {
    const res = await fetch(`https://api.openweathermap.org/data/2.5/weather?q=London&appid=${process.env.WEATHER_API_KEY}`);
    const data = await res.json();
    if (res.ok) {
      console.log("✅ Weather WORKS:", data.weather[0].description);
    } else {
      console.error("❌ Weather ERROR:", data.message || data);
    }
  } catch (err) {
    console.error("❌ Weather ERROR:", err.message);
  }
}

async function testNews() {
  console.log("\n🔹 4) Testing News API...");
  try {
    const res = await fetch(`https://newsapi.org/v2/top-headlines?country=us&apiKey=${process.env.NEWS_API_KEY}`);
    const data = await res.json();
    if (res.ok) {
      console.log("✅ News WORKS. Articles:", data.articles.length);
    } else {
      console.error("❌ News ERROR:", data.message || data);
    }
  } catch (err) {
    console.error("❌ News ERROR:", err.message);
  }
}

async function runTests() {
  await testOpenAI();
  await testPolly();
  await testWeather();
  await testNews();
}

runTests();
