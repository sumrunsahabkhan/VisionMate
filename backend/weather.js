import fetch from "node-fetch";
import dotenv from "dotenv";
dotenv.config();

export async function getWeather(city = "Islamabad") {
  const apiKey = process.env.WEATHER_API_KEY;
  const url = `https://api.openweathermap.org/data/2.5/weather?q=${city}&appid=${apiKey}&units=metric`;

  try {
    const res = await fetch(url);
    const data = await res.json();
    
    if (res.status === 401) {
      return "I'm sorry, my weather service key is not active yet.";
    }

    if (data.cod !== 200) {
      return `I couldn't find the weather for ${city}.`;
    }

    const temp = Math.round(data.main.temp);
    const desc = data.weather[0].description;
    
    return `The current temperature in ${city} is ${temp} degrees with ${desc}.`;
  } catch (error) {
    return "I am having trouble connecting to the weather service.";
  }
}
