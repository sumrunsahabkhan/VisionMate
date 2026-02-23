import fetch from "node-fetch";
import { config } from "../config/env.js";

export async function getNews(country = "pk") {
  const url = `https://newsapi.org/v2/top-headlines?country=${country}&apiKey=${config.newsApiKey}`;
  try {
    const res = await fetch(url);
    const data = await res.json();
    if (!data.articles || data.articles.length === 0) return "I couldn't find any news headlines right now.";
    return data.articles.slice(0, 3).map(a => a.title).join(". ");
  } catch (error) {
    return "I am having trouble accessing the news right now.";
  }
}
