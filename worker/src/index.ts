import { buildSystemPrompt } from './promptBuilder';

/**
 * Whispr's single server-side function — now hosted on Cloudflare Workers
 * instead of Firebase Cloud Functions, to avoid requiring a card on file
 * (Firebase Blaze) for something this small. Logic is identical to the
 * original functions/src/index.ts: hold the OpenRouter key, forward the
 * request, validate the response shape, retry once on failure. No
 * database, no Auth, no concept of a user — exactly as in Section 8 of
 * the implementation plan, just on different hosting.
 */

export interface Env {
  // Set via: wrangler secret put OPENROUTER_API_KEY
  OPENROUTER_API_KEY: string;
}

const PRIMARY_MODEL = 'anthropic/claude-3.5-haiku';
const FALLBACK_MODEL = 'openai/gpt-4o-mini';
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

// Permissive CORS so the Flutter app (running from any origin during dev,
// and from no "origin" at all on a real device) can call this Worker.
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

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

async function handleCallAI(request: Request, env: Env): Promise<Response> {
  let data: CallAIRequest;
  try {
    data = (await request.json()) as CallAIRequest;
  } catch {
    return jsonResponse({ error: 'Request body must be valid JSON.' }, 400);
  }

  if (!data.inputType || !data.deviceTimezone || !data.currentDateTime) {
    return jsonResponse({ error: 'Missing required fields.' }, 400);
  }
  if (data.inputType === 'text' && !data.text) {
    return jsonResponse({ error: 'Text input requires a "text" field.' }, 400);
  }
  if (data.inputType === 'voice' && (!data.audioData || !data.mimeType)) {
    return jsonResponse(
      { error: 'Voice input requires "audioData" (base64) and "mimeType".' },
      400
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
            input_audio: {
              data: data.audioData,
              format: data.mimeType!.split('/')[1] ?? 'm4a',
            },
          },
        ];

  const apiKey = env.OPENROUTER_API_KEY;
  if (!apiKey) {
    // Misconfiguration, not a client error — surfaced as 500 so it's
    // obviously a server-side setup problem during testing.
    return jsonResponse(
      { error: 'Server is missing OPENROUTER_API_KEY — set it via wrangler secret put.' },
      500
    );
  }

  const primaryModel = data.inputType === 'voice' ? AUDIO_MODEL : PRIMARY_MODEL;

  try {
    const result = await callOpenRouter(apiKey, primaryModel, systemPrompt, userContent);
    return jsonResponse(result);
  } catch (primaryError) {
    console.warn('Primary model failed, retrying with fallback:', primaryError);
    try {
      if (data.inputType === 'voice') {
        // Retrying voice against a non-audio-capable fallback would just
        // fail again the same way — don't bother.
        throw primaryError;
      }
      const result = await callOpenRouter(apiKey, FALLBACK_MODEL, systemPrompt, userContent);
      return jsonResponse(result);
    } catch (fallbackError) {
      console.error('Fallback model also failed:', fallbackError);
      return jsonResponse(
        { error: "Couldn't get a usable response from the AI. Please try again." },
        500
      );
    }
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Only POST is supported.' }, 405);
    }

    try {
      return await handleCallAI(request, env);
    } catch (err) {
      console.error('Unhandled error in callAI Worker:', err);
      return jsonResponse({ error: 'Internal server error.' }, 500);
    }
  },
};
