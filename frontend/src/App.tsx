import "@patternfly/react-core/dist/styles/base.css";
import {
  Alert,
  AlertVariant,
  Bullseye,
  EmptyState,
  EmptyStateBody,
  Grid,
  GridItem,
  Page,
  PageSection,
  Title,
} from "@patternfly/react-core";
import { useState } from "react";
import { postChat } from "./api/packmateApi";
import { ErrorState, LoadingState } from "./components/LoadingState";
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
    <Page>
      <PageSection isWidthLimited>
        <Title headingLevel="h1" size="2xl">
          Packmate
        </Title>
        <p style={{ marginTop: "0.5rem", maxWidth: "48rem" }}>
          Intelligent packing recommendations powered by weather, traveler profile, and
          deterministic baggage rules.
        </p>
      </PageSection>

      <PageSection isWidthLimited>
        <Grid hasGutter>
          <GridItem span={12} lg={5}>
            <TripForm
              values={formValues}
              onChange={setFormValues}
              onSubmit={handleSubmit}
              isSubmitting={status === "loading"}
              validationError={validationError}
            />
          </GridItem>

          <GridItem span={12} lg={7}>
            {status === "idle" && (
              <Bullseye style={{ minHeight: "20rem" }}>
                <EmptyState variant="full">
                  <EmptyStateBody>
                    Fill in your trip details and generate a structured packing list.
                  </EmptyStateBody>
                </EmptyState>
              </Bullseye>
            )}

            {status === "loading" && <LoadingState />}

            {status === "error" && requestError && (
              <ErrorState title="Request failed" message={requestError} />
            )}

            {status === "success" && response && <PackingResults response={response} />}

            {status === "success" && !response && (
              <Alert variant={AlertVariant.warning} title="Empty response" isInline>
                The backend returned no packing data.
              </Alert>
            )}
          </GridItem>
        </Grid>
      </PageSection>
    </Page>
  );
}
