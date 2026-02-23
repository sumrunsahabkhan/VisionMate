import { PollyClient, SynthesizeSpeechCommand } from "@aws-sdk/client-polly";
import { config } from "../config/env.js";

const polly = new PollyClient({
  region: config.aws.region,
  credentials: {
    accessKeyId: config.aws.accessKeyId,
    secretAccessKey: config.aws.secretAccessKey,
  },
});

export async function speakPolly(text) {
  const params = {
    Text: text,
    OutputFormat: "mp3",
    VoiceId: "Joanna",
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
