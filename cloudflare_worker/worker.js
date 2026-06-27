/**
 * Whispr — callAI Cloudflare Worker
 * Section 8 of the Implementation Plan
 *
 * EXACTLY ONE function. Stateless. Holds the OpenRouter API key.
 * Forwards text or audio to OpenRouter, returns its raw JSON response.
 * Knows nothing about reminders, triggers, users, or storage.
 *
 * Deploy: wrangler deploy
 * Set secret: wrangler secret put OPENROUTER_API_KEY
 */

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const PRIMARY_MODEL = 'anthropic/claude-3-5-haiku';
const FALLBACK_MODEL = 'openai/gpt-4o-mini';
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// ---------------------------------------------------------------------------
// System prompt builder (Section 6.2)
// ---------------------------------------------------------------------------
function buildSystemPrompt(deviceTimezone, currentDateTime) {
  return `You are an AI assistant for Whispr, a reminder app. 
Your job is to parse natural language input (typed text OR audio in English, Roman Urdu, or mixed) 
into a structured JSON reminder. 

CONTEXT:
- Current date/time: ${currentDateTime}
- User's timezone: ${deviceTimezone}

LANGUAGE:
- Support English, Roman Urdu (e.g. "subha", "kal", "yaad krana"), and code-switched sentences mixing both.
- No separate language detection step is needed — handle it natively.

RULES:
1. Only create FUTURE reminders. If the input describes something already completed, return a graceful error message — do NOT force a future interpretation.
2. Ambiguity handling:
   - If a detail is missing but there is a safe, common default (e.g. "subha" with no exact hour → 9:00 AM), use it and note it in assumptionsMade.
   - If the missing detail materially changes the outcome (e.g. "thori dair me" with no anchor), return needs_clarification.
3. Multi-task detection: if the sentence clearly describes TWO distinct tasks joined by "and"/"aur", return multi_task_detected.
4. Casual mentions (e.g. "kal meeting hai" — no explicit reminder request): return needs_clarification as a gentle offer ("Want me to remind you about this?").
5. Resolve ALL relative dates to absolute ISO 8601 using the current date above. Never return relative strings.
6. Floating/religious dates (Eid, etc.): provide your best estimate and mark it as approximate in assumptionsMade.
7. Self-corrections: if the user says "10 baje... nahi 11 baje", resolve to the final stated intent (11:00).
8. If multiple trigger times are stated for one task (e.g. "2pm aur 5pm"), return ONE ready response with multiple entries in the triggers array.

OUTPUT: Return ONLY valid JSON matching one of the three shapes below. No markdown, no explanation, no preamble.

SHAPE A — ready:
{
  "responseType": "ready",
  "taskTitle": "string",
  "dueAt": "ISO 8601 string | null",
  "triggers": [{ "fireAt": "ISO 8601", "label": "string", "kind": "fixed_time|offset_before_due" }],
  "recurrence": { "type": "daily|weekly|custom_days", "daysOfWeek": [0-6]|null, "timesOfDay": ["HH:MM"], "endDate": "ISO 8601|null" } | null,
  "assumptionsMade": ["plain-language string explaining any default applied"]
}

SHAPE B — needs_clarification:
{
  "responseType": "needs_clarification",
  "question": "string (exact question to show the user)",
  "quickReplyOptions": ["option1", "option2"] | null,
  "partialParse": { "taskTitle": "...", ... }
}

SHAPE C — multi_task_detected:
{
  "responseType": "multi_task_detected",
  "interpretationSingleTask": { ...Shape A fields... },
  "interpretationTwoTasks": [{ ...Shape A fields... }, { ...Shape A fields... }]
}`;
}

// ---------------------------------------------------------------------------
// OpenRouter caller with fallback retry (Section 6.4)
// ---------------------------------------------------------------------------
async function callOpenRouter(apiKey, messages, model) {
  const res = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://whispr.app',
      'X-Title': 'Whispr',
    },
    body: JSON.stringify({
      model,
      messages,
      response_format: { type: 'json_object' },
      max_tokens: 1024,
      temperature: 0.1, // Low temperature for reliable structured output.
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenRouter ${res.status}: ${err}`);
  }
  return res.json();
}

async function callWithFallback(apiKey, messages) {
  try {
    return await callOpenRouter(apiKey, messages, PRIMARY_MODEL);
  } catch (primaryErr) {
    console.warn(`Primary model failed (${PRIMARY_MODEL}), retrying with fallback:`, primaryErr.message);
    return await callOpenRouter(apiKey, messages, FALLBACK_MODEL);
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
export default {
  async fetch(request, env) {
    // CORS pre-flight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      });
    }

    if (request.method !== 'POST') {
      return jsonError('Method not allowed', 405);
    }

    const apiKey = env.OPENROUTER_API_KEY;
    if (!apiKey) {
      return jsonError('Server misconfiguration: missing API key', 500);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return jsonError('Invalid JSON body', 400);
    }

    const { inputType, text, audioData, mimeType, deviceTimezone, currentDateTime, currentClarificationContext } = body;
    if (!inputType || !deviceTimezone || !currentDateTime) {
      return jsonError('Missing required fields: inputType, deviceTimezone, currentDateTime', 400);
    }

    const systemPrompt = buildSystemPrompt(deviceTimezone, currentDateTime);

    let userContent;
    if (inputType === 'voice') {
      // Section 6.5 — audio direct to AI.
      if (!audioData || !mimeType) {
        return jsonError('Voice input requires audioData and mimeType', 400);
      }
      userContent = [
        {
          type: 'text',
          text: 'Listen to this audio clip and return a structured reminder JSON as described in the system prompt. Do not transcribe — return only the JSON interpretation.',
        },
        {
          type: 'image_url', // OpenRouter audio attachment format.
          image_url: {
            url: `data:${mimeType};base64,${audioData}`,
          },
        },
      ];
    } else {
      // Text input (with optional clarification context).
      let userText = text;
      if (currentClarificationContext) {
        userText = `[Prior partial parse: ${JSON.stringify(currentClarificationContext)}]\n\nUser reply: ${text}`;
      }
      userContent = userText;
    }

    const messages = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userContent },
    ];

    let openRouterResponse;
    try {
      openRouterResponse = await callWithFallback(apiKey, messages);
    } catch (err) {
      console.error('OpenRouter call failed:', err);
      return jsonError('AI service temporarily unavailable — please try again.', 503);
    }

    // Extract the content from OpenRouter's response envelope.
    const rawContent = openRouterResponse?.choices?.[0]?.message?.content;
    if (!rawContent) {
      return jsonError('Empty response from AI model', 502);
    }

    // Parse and validate the JSON.
    let parsed;
    try {
      parsed = JSON.parse(rawContent);
    } catch {
      return jsonError('AI returned non-JSON response — please rephrase and try again.', 502);
    }

    const validTypes = ['ready', 'needs_clarification', 'multi_task_detected'];
    if (!validTypes.includes(parsed.responseType)) {
      return jsonError(`Unexpected responseType: ${parsed.responseType}`, 502);
    }

    return new Response(JSON.stringify(parsed), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  },
};

function jsonError(message, status = 400) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
