import { PollyClient, SynthesizeSpeechCommand } from "@aws-sdk/client-polly";
import dotenv from "dotenv";
dotenv.config();

const polly = new PollyClient({
  region: process.env.AWS_REGION || "us-east-1",
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

export async function speakPolly(text) {
  const params = {
    Text: text,
    OutputFormat: "mp3",
    VoiceId: "Joanna", // English US Female
    LanguageCode: "en-US",
    Engine: "neural" 
  };

  try {
    const command = new SynthesizeSpeechCommand(params);
    const data = await polly.send(command);
    const chunks = [];
    for await (let chunk of data.AudioStream) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  } catch (error) {
    console.error("Polly Error:", error.message);
    throw error;
  }
}
