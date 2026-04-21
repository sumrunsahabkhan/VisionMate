class WalkthroughStepConfig {
  final String text;
  final int nextStep;
  final bool isWaitingForAction;
  final bool isAwake;
  final bool isVoiceStep;

  WalkthroughStepConfig({
    required this.text,
    required this.nextStep,
    this.isWaitingForAction = false,
    this.isAwake = false,
    this.isVoiceStep = false,
  });
}

class WalkthroughUseCase {
  WalkthroughStepConfig getStepConfig(int step) {
    switch (step) {
      case 0:
        return WalkthroughStepConfig(
          text: "Welcome to VisionMate. I am your personal voice assistant, designed to help you without looking at the screen. I will guide you step by step. Let's begin.",
          nextStep: 1,
        );
      case 1:
        return WalkthroughStepConfig(
          text: "To wake me up anytime, tap the screen three times quickly. Please try tapping three times now.",
          nextStep: 2,
        );
      case 2:
        return WalkthroughStepConfig(text: "", nextStep: 3, isWaitingForAction: true);
      case 3:
        return WalkthroughStepConfig(
          text: "Perfect. I am awake now. You can also wake me using your voice. After I go silent, say Hello.",
          nextStep: 4,
        );
      case 4:
        return WalkthroughStepConfig(text: "", nextStep: 5, isWaitingForAction: true, isVoiceStep: true);
      case 5:
        return WalkthroughStepConfig(
          text: "Great. I heard you. If you ever want to know my current state, tap the screen once. Please tap one time now.",
          nextStep: 6,
        );
      case 6:
        return WalkthroughStepConfig(text: "", nextStep: 7, isWaitingForAction: true);
      case 7:
        return WalkthroughStepConfig(
          text: "Yes, I am listening. Now, let's learn how to go to standby. Swipe your finger down on the screen. Please swipe down now.",
          nextStep: 8,
        );
      case 8:
        return WalkthroughStepConfig(text: "", nextStep: 9, isWaitingForAction: true);
      case 9:
        return WalkthroughStepConfig(
          text: "VisionMate is now on standby. Now, wake me up one last time by tapping three times.",
          nextStep: 10,
        );
      case 10:
        return WalkthroughStepConfig(text: "", nextStep: 11, isWaitingForAction: true);
      case 11:
        return WalkthroughStepConfig(
          text: "Excellent. I am back. Now, let me tell you what I can help you with.",
          nextStep: 12,
          isAwake: true,
        );
      case 12:
        return WalkthroughStepConfig(
          text: "I can provide you with the current time, date, and your phone's battery level anytime, even without internet.",
          nextStep: 13,
          isAwake: true,
        );
      case 13:
        return WalkthroughStepConfig(
          text: "My Smart Camera is very powerful. I can identify colors of your clothes or objects around you. I can also read printed text from documents and even browse and read PDF files stored on your phone. Just say: Scan Text, or Read PDF, to start.",
          nextStep: 14,
          isAwake: true,
        );
      case 14:
        return WalkthroughStepConfig(
          text: "For your safety, if you ever need help, just say: SOS, to alert your emergency contacts immediately.",
          nextStep: 15,
          isAwake: true,
        );
      case 15:
        return WalkthroughStepConfig(
          text: "When you have internet, I can answer your questions, read news, or give weather reports. You can also customize my voice speed and pitch in settings by saying: Open settings.",
          nextStep: 16,
          isAwake: true,
        );
      case 16:
        return WalkthroughStepConfig(
          text: "You're all set. Remember: One tap for status. Two taps to repeat. Three taps to wake me up. And swipe down for sleep. Say Hello or tap three times whenever you need me. Welcome to VisionMate.",
          nextStep: 100,
        );
      default:
        return WalkthroughStepConfig(text: "", nextStep: 100);
    }
  }
}
