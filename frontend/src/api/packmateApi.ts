import {
  ApiError,
  NetworkError,
  type ChatRequest,
  type PackingResponse,
} from "../models/packmate";

const CHAT_ENDPOINT = "/api/v1/chat";

export async function postChat(request: ChatRequest): Promise<PackingResponse> {
  let response: Response;

  try {
    response = await fetch(CHAT_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(request),
    });
  } catch {
    throw new NetworkError();
  }

  if (!response.ok) {
    let detail = `Request failed with status ${response.status}.`;

    try {
      const payload = (await response.json()) as { detail?: string | { msg?: string }[] };
      if (typeof payload.detail === "string") {
        detail = payload.detail;
      } else if (Array.isArray(payload.detail) && payload.detail[0]?.msg) {
        detail = payload.detail.map((item) => item.msg).join(" ");
      }
    } catch {
      // Keep generic detail when response body is not JSON.
    }

    throw new ApiError(response.status, detail);
  }

  return (await response.json()) as PackingResponse;
}
