import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";
import { BaggageWarnings } from "../components/BaggageWarnings";
import { PackingList } from "../components/PackingList";
import { PackingResults } from "../components/PackingResults";
import { defaultTripFormValues } from "../models/formDefaults";
import { TripForm } from "./TripForm";
import type { PackingResponse } from "../models/packmate";

const sampleResponse: PackingResponse = {
  destination: "Rome",
  start_date: "2026-07-21",
  end_date: "2026-07-23",
  weather_summary: {
    location: "Rome",
    overview: "Warm and sunny.",
    min_temperature: "18°C",
    max_temperature: "30°C",
    conditions: "Clear",
  },
  packing_items: [
    {
      name: "T-shirt",
      category: "Clothes",
      quantity: 3,
      reason: "Hot weather",
      essential: true,
    },
  ],
  warnings: ["Bring sunscreen"],
  baggage_warnings: ["Demo rule: liquids in cabin baggage must be in containers of 100 ml or less."],
  profile_considerations: ["Business trip: include professional attire."],
  rules_disclaimer: "DEMONSTRATION RULES ONLY.",
  language: "fr",
};

describe("TripForm", () => {
  it("renders the trip form fields", () => {
    render(
      <TripForm
        values={defaultTripFormValues}
        onChange={vi.fn()}
        onSubmit={vi.fn()}
        isSubmitting={false}
      />,
    );

    expect(screen.getByLabelText(/Travel message/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Trip type/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Baggage type/i)).toBeInTheDocument();
    expect(screen.getByRole("switch", { name: /Share sensitive notes with model provider/i })).toBeInTheDocument();
  });

  it("keeps sensitive consent disabled by default", () => {
    render(
      <TripForm
        values={defaultTripFormValues}
        onChange={vi.fn()}
        onSubmit={vi.fn()}
        isSubmitting={false}
      />,
    );

    expect(
      screen.getByRole("switch", { name: /Share sensitive notes with model provider/i }),
    ).not.toBeChecked();
  });

  it("shows a warning when sensitive consent is enabled", async () => {
    const user = userEvent.setup();

    function Wrapper() {
      const [values, setValues] = useState(defaultTripFormValues);
      return (
        <TripForm
          values={values}
          onChange={setValues}
          onSubmit={vi.fn()}
          isSubmitting={false}
        />
      );
    }

    render(<Wrapper />);

    await user.click(screen.getByRole("switch", { name: /Share sensitive notes with model provider/i }));

    expect(
      screen.getByText(/Sensitive data transmission enabled/i),
    ).toBeInTheDocument();
  });

  it("does not default baggage type to cabin", () => {
    render(
      <TripForm
        values={defaultTripFormValues}
        onChange={vi.fn()}
        onSubmit={vi.fn()}
        isSubmitting={false}
      />,
    );

    expect(screen.getByLabelText(/Baggage type/i)).toHaveValue("");
  });
});

describe("PackingResults", () => {
  it("displays structured packing response sections", () => {
    render(<PackingResults response={sampleResponse} />);

    expect(screen.getByText("Trip overview")).toBeInTheDocument();
    expect(screen.getAllByText("Rome").length).toBeGreaterThan(0);
    expect(screen.getByText("Weather summary")).toBeInTheDocument();
    expect(screen.getByText("Packing list")).toBeInTheDocument();
    expect(screen.getByText("Baggage warnings")).toBeInTheDocument();
    expect(screen.getByText(/DEMONSTRATION RULES ONLY/i)).toBeInTheDocument();
  });
});

describe("BaggageWarnings", () => {
  it("renders baggage warnings", () => {
    render(<BaggageWarnings warnings={sampleResponse.baggage_warnings} />);

    expect(screen.getByText(/100 ml or less/i)).toBeInTheDocument();
  });
});

describe("PackingList", () => {
  it("shows essential and optional labels", () => {
    render(<PackingList items={sampleResponse.packing_items} />);

    expect(screen.getByText("T-shirt")).toBeInTheDocument();
    expect(screen.getByText("Essential")).toBeInTheDocument();
  });
});

describe("sensitive notes storage", () => {
  it("does not persist sensitive notes in localStorage", async () => {
    const user = userEvent.setup();
    const setItemSpy = vi.spyOn(Storage.prototype, "setItem");

    render(
      <TripForm
        values={{
          ...defaultTripFormValues,
          medicalNotes: "Requires insulin refrigeration",
          shareSensitiveNotes: true,
        }}
        onChange={vi.fn()}
        onSubmit={vi.fn()}
        isSubmitting={false}
      />,
    );

    await user.type(screen.getByLabelText("Medical or accessibility notes"), " extra");

    expect(setItemSpy).not.toHaveBeenCalled();
    setItemSpy.mockRestore();
  });
});
