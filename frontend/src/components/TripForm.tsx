import {
  Alert,
  AlertVariant,
  Button,
  Form,
  FormGroup,
  FormHelperText,
  FormSelect,
  FormSelectOption,
  Grid,
  GridItem,
  Switch,
  TextArea,
  TextInput,
  Title,
} from "@patternfly/react-core";
import { useState, type FormEvent } from "react";
import type { TripFormValues } from "../models/packmate";

interface TripFormProps {
  values: TripFormValues;
  onChange: (values: TripFormValues) => void;
  onSubmit: () => void;
  isSubmitting: boolean;
  validationError?: string | null;
}

export function TripForm({
  values,
  onChange,
  onSubmit,
  isSubmitting,
  validationError,
}: TripFormProps) {
  const [showSensitiveWarning, setShowSensitiveWarning] = useState(false);

  const updateField = <K extends keyof TripFormValues>(key: K, value: TripFormValues[K]) => {
    onChange({ ...values, [key]: value });
  };

  const handleSensitiveConsentChange = (
    _event: FormEvent<HTMLInputElement>,
    checked: boolean,
  ) => {
    updateField("shareSensitiveNotes", checked);
    setShowSensitiveWarning(checked);
  };

  return (
    <Form
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit();
      }}
    >
      <Title headingLevel="h2" size="lg">
        Plan your trip
      </Title>

      {validationError && (
        <Alert
          variant={AlertVariant.danger}
          title="Validation error"
          isInline
          style={{ marginTop: "1rem" }}
        >
          {validationError}
        </Alert>
      )}

      <Grid hasGutter style={{ marginTop: "1rem" }}>
        <GridItem span={12}>
          <FormGroup label="Travel message" isRequired fieldId="travel-message">
            <TextArea
              id="travel-message"
              value={values.message}
              onChange={(_event, value) => updateField("message", value)}
              placeholder="Example: I am travelling to Rome next week with cabin baggage."
              rows={4}
              isRequired
            />
            <FormHelperText>
              Describe your destination, dates, and travel context.
            </FormHelperText>
          </FormGroup>
        </GridItem>

        <GridItem span={12} md={6}>
          <FormGroup label="Trip type" isRequired fieldId="trip-type">
            <FormSelect
              id="trip-type"
              value={values.tripType}
              onChange={(_event, value) => updateField("tripType", value as TripFormValues["tripType"])}
              isRequired
            >
              <FormSelectOption value="leisure" label="Leisure" />
              <FormSelectOption value="business" label="Business" />
            </FormSelect>
          </FormGroup>
        </GridItem>

        <GridItem span={12} md={6}>
          <FormGroup label="Baggage type" isRequired fieldId="baggage-type">
            <FormSelect
              id="baggage-type"
              value={values.baggageType}
              onChange={(_event, value) =>
                updateField("baggageType", value as TripFormValues["baggageType"])
              }
              isRequired
            >
              <FormSelectOption value="" label="Select baggage type" />
              <FormSelectOption value="cabin" label="Cabin baggage" />
              <FormSelectOption value="checked" label="Checked baggage" />
              <FormSelectOption value="both" label="Cabin and checked baggage" />
            </FormSelect>
            <FormHelperText>
              Select your baggage type explicitly to validate restrictions.
            </FormHelperText>
          </FormGroup>
        </GridItem>

        <GridItem span={12} md={6}>
          <FormGroup label="Activities" fieldId="activities">
            <TextInput
              id="activities"
              value={values.activities}
              onChange={(_event, value) => updateField("activities", value)}
              placeholder="hiking, museums"
            />
            <FormHelperText>Comma-separated list.</FormHelperText>
          </FormGroup>
        </GridItem>

        <GridItem span={12} md={6}>
          <FormGroup label="Clothing preferences" fieldId="clothing-preferences">
            <TextInput
              id="clothing-preferences"
              value={values.clothingPreferences}
              onChange={(_event, value) => updateField("clothingPreferences", value)}
              placeholder="casual, formal"
            />
          </FormGroup>
        </GridItem>

        <GridItem span={12}>
          <FormGroup label="Available items" fieldId="available-items">
            <TextInput
              id="available-items"
              value={values.availableItems}
              onChange={(_event, value) => updateField("availableItems", value)}
              placeholder="running shoes, rain jacket"
            />
          </FormGroup>
        </GridItem>

        <GridItem span={12}>
          <FormGroup label="Medical or accessibility notes" fieldId="medical-notes">
            <TextArea
              id="medical-notes"
              value={values.medicalNotes}
              onChange={(_event, value) => updateField("medicalNotes", value)}
              placeholder="Optional notes used locally for generic guidance."
              rows={3}
            />
            <FormHelperText>
              These notes are not transmitted to the model by default. They are used only
              for generic backend guidance unless you explicitly consent below.
            </FormHelperText>
          </FormGroup>
        </GridItem>

        <GridItem span={12}>
          <FormGroup fieldId="share-sensitive-notes">
            <Switch
              id="share-sensitive-notes"
              aria-label="Share sensitive notes with model provider"
              label="I consent to transmit medical or accessibility notes to the model provider"
              isChecked={values.shareSensitiveNotes}
              onChange={handleSensitiveConsentChange}
            />
          </FormGroup>
        </GridItem>

        {showSensitiveWarning && values.shareSensitiveNotes && (
          <GridItem span={12}>
            <Alert
              variant={AlertVariant.warning}
              title="Sensitive data transmission enabled"
              isInline
            >
              Your medical or accessibility notes will be transmitted to the model provider
              to tailor recommendations. They are never stored in the browser or logged locally.
            </Alert>
          </GridItem>
        )}

        <GridItem span={12}>
          <Button variant="primary" type="submit" isDisabled={isSubmitting}>
            {isSubmitting ? "Generating packing list..." : "Generate packing list"}
          </Button>
        </GridItem>
      </Grid>
    </Form>
  );
}
