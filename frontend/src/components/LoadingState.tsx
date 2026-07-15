import {
  Alert,
  AlertVariant,
  Bullseye,
  EmptyState,
  EmptyStateBody,
  Spinner,
} from "@patternfly/react-core";

interface LoadingStateProps {
  message?: string;
}

export function LoadingState({ message = "Analyzing your trip..." }: LoadingStateProps) {
  return (
    <Bullseye style={{ minHeight: "12rem" }}>
      <EmptyState variant="full">
        <Spinner size="xl" aria-label="Loading" />
        <EmptyStateBody>{message}</EmptyStateBody>
      </EmptyState>
    </Bullseye>
  );
}

interface ErrorStateProps {
  title: string;
  message: string;
}

export function ErrorState({ title, message }: ErrorStateProps) {
  return (
    <Alert variant={AlertVariant.danger} title={title} isInline>
      {message}
    </Alert>
  );
}
