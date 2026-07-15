import { describe, expect, it, vi } from "vitest";
import { postChat } from "../api/packmateApi";
import { ApiError, NetworkError, type ChatRequest } from "../models/packmate";

const sampleRequest: ChatRequest = {
  message: "Trip to Rome",
  traveler_profile: {
    trip_type: "leisure",
    baggage_type: "cabin",
    activities: [],
    clothing_preferences: [],
    share_sensitive_notes_with_model: false,
  },
};

describe("postChat", () => {
  it("calls POST /api/v1/chat with a JSON body", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        destination: "Rome",
        start_date: "2026-07-21",
        end_date: "2026-07-23",
        weather_summary: { location: "Rome", overview: "Warm." },
        packing_items: [],
        warnings: [],
        baggage_warnings: [],
        profile_considerations: [],
        rules_disclaimer: "Demo",
        language: "fr",
      }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await postChat(sampleRequest);

    expect(fetchMock).toHaveBeenCalledWith("/api/v1/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(sampleRequest),
    });
  });

  it("throws ApiError for backend failures", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 503,
        json: async () => ({ detail: "LLM is not configured." }),
      }),
    );

    await expect(postChat(sampleRequest)).rejects.toEqual(
      new ApiError(503, "LLM is not configured."),
    );
  });

  it("throws NetworkError when fetch fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));

    await expect(postChat(sampleRequest)).rejects.toBeInstanceOf(NetworkError);
  });
});
