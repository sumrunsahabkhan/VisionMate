class VoiceResponses {
  static String helpResponse() {
    return """
I can assist you with several commands.
You can wake me up using phrases like: Vision Mate, Hey Vision, Hello, or Hi.
I can provide the current time, today's date, or your battery percentage.
I can also help with color detection, and SOS emergency.
For guidance on touch controls, say Gestures, or Manual.
To put me in standby, say Go to Sleep, or Stop.
How can I help you right now?
""";
  }

  static String manualResponse() {
    return """
Vision Mate supports intuitive touch gestures.
Triple tap anywhere to wake me up instantly.
Double tap has a smart function. If I am speaking, a double tap will silence me immediately. If I am silent, it will repeat my last sentence.
To send me to standby mode, simply swipe down anywhere on the screen.
I will also vibrate to confirm when I wake up or go to sleep.
You can also use the smart camera for color, and object detection.
""";
  }
}
