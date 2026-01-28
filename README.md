# Voice Dataset Maker

A macOS application for creating high-quality voice datasets suitable for fine-tuning Qwen3-TTS and other text-to-speech models.

## Requirements

- macOS 13.0+
- Swift 5.9+
- Microphone access

## Build & Run

```bash
cd VoiceRecorder
swift build
.build/debug/VoiceRecorder
```

## Usage

1. **Launch** the app and grant microphone access when prompted
2. **Enter your voice name** (e.g., "sam") - recordings will be saved to `recordings/{voice_name}/`
3. **Read the transcript** displayed on screen
4. **Press Record** to start recording your voice
5. **Press Stop** when finished reading
6. **Review** the recording with playback controls
7. **Re-record** if needed, or continue to the next transcript
8. **Navigate** between transcripts using Previous/Next buttons
9. **Add custom transcripts** using the Add button or edit files directly

## Output Format

Recordings are saved to `recordings/{voice_name}/` with paired files:

```
recordings/sam/
├── greeting.wav
├── greeting.txt
├── question.wav
├── question.txt
└── ...
```

**Audio format:** 44100Hz, 16-bit, mono WAV

Each `.txt` file contains the exact transcript text for its corresponding `.wav` file.

## Transcripts

Includes 18 diverse transcripts covering:
- Emotional range (calm, excited, sad, skeptical)
- Conversational patterns (greetings, farewells, questions)
- Phonetic variety (tongue twisters, technical terms)
- Sentence types (statements, exclamations, instructions)
- Numbers and dates

## Adding Custom Transcripts

**Via the app:** Use the "Add Transcript" button to create new entries.

**Manually:** Add `.txt` files to the `transcripts/` directory. Each file should contain one transcript sentence/paragraph.

## License

MIT
