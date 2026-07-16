import "@patternfly/react-core/dist/styles/base.css";
import { useState } from "react";
import { postChat } from "./api/packmateApi";
import { ErrorState, LoadingState } from "./components/LoadingState";
import { LabShell } from "./components/LabShell";
import { PackingResults } from "./components/PackingResults";
import { TripForm } from "./components/TripForm";
import { defaultTripFormValues } from "./models/formDefaults";
import {
  ApiError,
  buildChatRequest,
  NetworkError,
  ValidationError,
  type PackingResponse,
  type TripFormValues,
} from "./models/packmate";

type AppStatus = "idle" | "loading" | "success" | "error";

function resolveActiveStep(status: AppStatus): number {
  if (status === "success") {
    return 4;
  }
  if (status === "loading") {
    return 3;
  }
  return 1;
}

export default function App() {
  const [formValues, setFormValues] = useState<TripFormValues>(defaultTripFormValues);
  const [status, setStatus] = useState<AppStatus>("idle");
  const [validationError, setValidationError] = useState<string | null>(null);
  const [requestError, setRequestError] = useState<string | null>(null);
  const [response, setResponse] = useState<PackingResponse | null>(null);

  const handleSubmit = async () => {
    setValidationError(null);
    setRequestError(null);

    let request;
    try {
      request = buildChatRequest(formValues);
    } catch (error) {
      const message =
        error instanceof ValidationError ? error.message : "Invalid form submission.";
      setValidationError(message);
      setStatus("error");
      return;
    }

    setStatus("loading");

    try {
      const result = await postChat(request);
      setResponse(result);
      setStatus("success");
    } catch (error) {
      if (error instanceof ApiError) {
        setRequestError(error.detail);
      } else if (error instanceof NetworkError) {
        setRequestError(error.message);
      } else {
        setRequestError("Unexpected error while generating the packing list.");
      }
      setStatus("error");
    }
  };

  return (
    <LabShell activeStep={resolveActiveStep(status)}>
      <div className="lab-content">
        <h1 className="lab-page-title">Create your packing plan</h1>
        <p className="lab-page-lead">
          Enter your trip details and traveler profile to generate a structured packing
          recommendation based on weather, profile, and deterministic baggage rules.
        </p>

        <TripForm
          values={formValues}
          onChange={setFormValues}
          onSubmit={handleSubmit}
          isSubmitting={status === "loading"}
          validationError={validationError}
        />

        {(status === "loading" || status === "success" || (status === "error" && requestError)) && (
          <div className="lab-results-panel">
            {status === "loading" && <LoadingState />}

            {status === "error" && requestError && (
              <ErrorState title="Request failed" message={requestError} />
            )}

            {status === "success" && response && <PackingResults response={response} />}

            {status === "success" && !response && (
              <div className="lab-empty" role="status">
                The backend returned no packing data.
              </div>
            )}
          </div>
        )}

        {status === "idle" && (
          <div className="lab-empty" style={{ marginTop: "2rem" }} role="status">
            Complete the form above and select Generate packing plan to view your report.
          </div>
        )}
      </div>
    </LabShell>
  );
}
