import { Alert, AlertVariant, Card, CardBody, CardTitle, List, ListItem } from "@patternfly/react-core";

interface BaggageWarningsProps {
  warnings: string[];
  title?: string;
}

export function BaggageWarnings({ warnings, title = "Baggage warnings" }: BaggageWarningsProps) {
  if (warnings.length === 0) {
    return null;
  }

  return (
    <Card>
      <CardTitle>{title}</CardTitle>
      <CardBody>
        <List isPlain>
          {warnings.map((warning) => (
            <ListItem key={warning}>
              <Alert variant={AlertVariant.warning} title={warning} isPlain isInline />
            </ListItem>
          ))}
        </List>
      </CardBody>
    </Card>
  );
}

interface WarningListProps {
  warnings: string[];
  title: string;
}

export function WarningList({ warnings, title }: WarningListProps) {
  if (warnings.length === 0) {
    return null;
  }

  return (
    <Card>
      <CardTitle>{title}</CardTitle>
      <CardBody>
        <List isPlain>
          {warnings.map((warning) => (
            <ListItem key={warning}>{warning}</ListItem>
          ))}
        </List>
      </CardBody>
    </Card>
  );
}

interface DisclaimerProps {
  disclaimer: string;
}

export function RulesDisclaimer({ disclaimer }: DisclaimerProps) {
  return (
    <Alert variant={AlertVariant.info} title="Baggage rules disclaimer" isInline>
      {disclaimer}
    </Alert>
  );
}
