import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import App from "./App";
import { postChat } from "./api/packmateApi";
import { ApiError, type PackingResponse } from "./models/packmate";

vi.mock("./api/packmateApi", () => ({
  postChat: vi.fn(),
}));

const mockedPostChat = vi.mocked(postChat);

const sampleResponse: PackingResponse = {
  destination: "Rome",
  start_date: "2026-07-21",
  end_date: "2026-07-23",
  weather_summary: {
    location: "Rome",
    overview: "Warm.",
  },
  packing_items: [],
  warnings: [],
  baggage_warnings: ["Demo baggage warning"],
  profile_considerations: [],
  rules_disclaimer: "DEMO",
  language: "fr",
};

describe("App", () => {
  beforeEach(() => {
    mockedPostChat.mockReset();
  });

  it("shows a loading state while waiting for the backend", async () => {
    mockedPostChat.mockImplementation(
      () =>
        new Promise((resolve) => {
          setTimeout(() => resolve(sampleResponse), 100);
        }),
    );

    const user = userEvent.setup();
    render(<App />);

    await user.type(
      screen.getByLabelText(/Travel message/i),
      "Je pars à Rome la semaine prochaine",
    );
    await user.selectOptions(screen.getByLabelText(/Baggage type/i), "cabin");
    await user.click(screen.getByRole("button", { name: /Generate packing list/i }));

    expect(screen.getByText(/Analyzing your trip/i)).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText("Trip overview")).toBeInTheDocument();
    });
  });

  it("displays backend errors", async () => {
    mockedPostChat.mockRejectedValue(new ApiError(503, "LLM is not configured."));

    const user = userEvent.setup();
    render(<App />);

    await user.type(screen.getByLabelText(/Travel message/i), "Trip to Rome");
    await user.selectOptions(screen.getByLabelText(/Baggage type/i), "cabin");
    await user.click(screen.getByRole("button", { name: /Generate packing list/i }));

    expect(await screen.findByText(/LLM is not configured/i)).toBeInTheDocument();
  });

  it("shows validation error when baggage type is missing", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.type(screen.getByLabelText(/Travel message/i), "Trip to Rome");
    await user.click(screen.getByRole("button", { name: /Generate packing list/i }));

    expect(await screen.findByText(/Baggage type is required/i)).toBeInTheDocument();
    expect(mockedPostChat).not.toHaveBeenCalled();
  });
});
