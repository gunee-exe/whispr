import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { buildSystemPrompt } from './promptBuilder';

/**
 * The ONE Cloud Function in this app — Section 8 of the implementation
 * plan. It exists purely because the OpenRouter API key can't safely live
 * inside the Flutter binary. It holds no database connection, knows
 * nothing about reminders/triggers/recurrence, and has no concept of a
 * user — it just forwards a request and returns OpenRouter's JSON.
 */

const OPENROUTER_API_KEY = defineSecret('OPENROUTER_API_KEY');

// Primary: fast, cheap, strong structured-output model (Section 6.4).
// Fallback retried automatically if the primary errors/times out.
const PRIMARY_MODEL = 'anthropic/claude-3.5-haiku';
const FALLBACK_MODEL = 'openai/gpt-4o-mini';

// Audio-capable model for voice input (Section 6.5) — not every model on
// OpenRouter accepts audio, so this is deliberately a separate, explicit
// config value rather than reusing PRIMARY_MODEL. Gemini's multimodal
// models are a solid default for direct audio input via OpenRouter.
const AUDIO_MODEL = 'google/gemini-2.0-flash-001';

interface CallAIRequest {
  inputType: 'text' | 'voice';
  text?: string;
  audioData?: string; // base64
  mimeType?: string;
  deviceTimezone: string;
  currentDateTime: string;
  currentClarificationContext?: Record<string, unknown>;
}

const RESPONSE_TYPES = ['ready', 'needs_clarification', 'multi_task_detected'];

function validateShape(parsed: unknown): Record<string, unknown> {
  if (typeof parsed !== 'object' || parsed === null) {
    throw new Error('Response is not a JSON object');
  }
  const obj = parsed as Record<string, unknown>;
  if (!RESPONSE_TYPES.includes(obj.responseType as string)) {
    throw new Error(`Invalid or missing responseType: ${obj.responseType}`);
  }
  return obj;
}

async function callOpenRouter(
  apiKey: string,
  model: string,
  systemPrompt: string,
  userContent: Array<Record<string, unknown>>
): Promise<Record<string, unknown>> {
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userContent },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenRouter error (${response.status}): ${errText}`);
  }

  const data = (await response.json()) as {
    choices: Array<{ message: { content: string } }>;
  };
  const rawContent = data.choices?.[0]?.message?.content;
  if (!rawContent) {
    throw new Error('OpenRouter returned no content');
  }

  const cleaned = rawContent.replace(/^```json\s*|\s*```$/g, '').trim();
  const parsed = JSON.parse(cleaned);
  return validateShape(parsed);
}

export const callAI = onCall(
  { secrets: [OPENROUTER_API_KEY], cors: true, timeoutSeconds: 60 },
  async (request) => {
    const data = request.data as CallAIRequest;

    if (!data.inputType || !data.deviceTimezone || !data.currentDateTime) {
      throw new HttpsError('invalid-argument', 'Missing required fields.');
    }
    if (data.inputType === 'text' && !data.text) {
      throw new HttpsError('invalid-argument', 'Text input requires a "text" field.');
    }
    if (data.inputType === 'voice' && (!data.audioData || !data.mimeType)) {
      throw new HttpsError(
        'invalid-argument',
        'Voice input requires "audioData" (base64) and "mimeType".'
      );
    }

    const systemPrompt = buildSystemPrompt({
      deviceTimezone: data.deviceTimezone,
      currentDateTime: data.currentDateTime,
      inputType: data.inputType,
      currentClarificationContext: data.currentClarificationContext,
    });

    const userContent =
      data.inputType === 'text'
        ? [{ type: 'text', text: data.text }]
        : [
            {
              type: 'text',
              text: 'Listen to this audio clip and parse it into a reminder per the system instructions.',
            },
            {
              type: 'input_audio',
              input_audio: { data: data.audioData, format: data.mimeType!.split('/')[1] ?? 'm4a' },
            },
          ];

    const apiKey = OPENROUTER_API_KEY.value();
    // Voice always uses the audio-capable model; text tries primary then
    // falls back automatically (Section 6.4).
    const primaryModel = data.inputType === 'voice' ? AUDIO_MODEL : PRIMARY_MODEL;

    try {
      return await callOpenRouter(apiKey, primaryModel, systemPrompt, userContent);
    } catch (primaryError) {
      console.warn('Primary model failed, retrying with fallback:', primaryError);
      try {
        // For voice, retrying with a non-audio-capable fallback would
        // simply fail again — only retry text input against the text
        // fallback model.
        if (data.inputType === 'voice') {
          throw primaryError;
        }
        return await callOpenRouter(apiKey, FALLBACK_MODEL, systemPrompt, userContent);
      } catch (fallbackError) {
        console.error('Fallback model also failed:', fallbackError);
        throw new HttpsError(
          'internal',
          "Couldn't get a usable response from the AI. Please try again."
        );
      }
    }
  }
);
