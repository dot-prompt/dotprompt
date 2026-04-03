import { createParser, type ParsedEvent, type ReconnectInterval } from "eventsource-parser";
import { type DotPromptEvent } from "./models.js";

/**
 * Creates an async generator for receiving SSE events from the dot-prompt API.
 * Uses fetch streaming and eventsource-parser for efficient parsing.
 * 
 * @param url - The /api/events URL.
 * @param apiKey - Optional API key for authorization.
 * @returns AsyncGenerator<DotPromptEvent>
 */
export async function* createEventStream(
  url: string,
  apiKey?: string
): AsyncGenerator<DotPromptEvent> {
  const headers: Record<string, string> = {
    "Accept": "text/event-stream",
  };

  if (apiKey) {
    headers["Authorization"] = `Bearer ${apiKey}`;
  }

  const response = await fetch(url, { headers });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to establish event stream: ${response.status} ${errorText}`);
  }

  if (response.body === null) {
      throw new Error("Response body is null");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();

  let resolve: (event: DotPromptEvent | null) => void;
  let eventQueue: DotPromptEvent[] = [];
  let isDone = false;

  const parser = createParser((event: ParsedEvent | ReconnectInterval) => {
    if (event.type === "event") {
      try {
        const data = JSON.parse(event.data);
        eventQueue.push(data as DotPromptEvent);
      } catch {
        // Log or handle malformed events?
      }
    }
  });

  try {
    while (true) {
      const { done, value } = await reader.read();
      
      if (done) {
        isDone = true;
        break;
      }

      parser.feed(decoder.decode(value, { stream: true }));

      while (eventQueue.length > 0) {
        yield eventQueue.shift()!;
      }
    }
  } finally {
    reader.releaseLock();
  }
}
