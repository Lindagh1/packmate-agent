import {
  Card,
  CardBody,
  CardTitle,
  DescriptionList,
  DescriptionListDescription,
  DescriptionListGroup,
  DescriptionListTerm,
  Grid,
  GridItem,
  Stack,
  StackItem,
} from "@patternfly/react-core";
import type { PackingResponse } from "../models/packmate";
import {
  BaggageWarnings,
  RulesDisclaimer,
  WarningList,
} from "./BaggageWarnings";
import { PackingList } from "./PackingList";
import { WeatherSummary } from "./WeatherSummary";

interface PackingResultsProps {
  response: PackingResponse;
}

export function PackingResults({ response }: PackingResultsProps) {
  return (
    <Stack hasGutter>
      <StackItem>
        <Card>
          <CardTitle>Trip overview</CardTitle>
          <CardBody>
            <DescriptionList isHorizontal>
              <DescriptionListGroup>
                <DescriptionListTerm>Destination</DescriptionListTerm>
                <DescriptionListDescription>{response.destination}</DescriptionListDescription>
              </DescriptionListGroup>
              <DescriptionListGroup>
                <DescriptionListTerm>Dates</DescriptionListTerm>
                <DescriptionListDescription>
                  {response.start_date} to {response.end_date}
                </DescriptionListDescription>
              </DescriptionListGroup>
              <DescriptionListGroup>
                <DescriptionListTerm>Language</DescriptionListTerm>
                <DescriptionListDescription>{response.language}</DescriptionListDescription>
              </DescriptionListGroup>
            </DescriptionList>
          </CardBody>
        </Card>
      </StackItem>

      <StackItem>
        <Grid hasGutter>
          <GridItem span={12} lg={6}>
            <WeatherSummary summary={response.weather_summary} />
          </GridItem>
          <GridItem span={12} lg={6}>
            <WarningList warnings={response.warnings} title="General warnings" />
          </GridItem>
        </Grid>
      </StackItem>

      <StackItem>
        <PackingList items={response.packing_items} />
      </StackItem>

      <StackItem>
        <BaggageWarnings warnings={response.baggage_warnings} />
      </StackItem>

      <StackItem>
        <WarningList
          warnings={response.profile_considerations}
          title="Profile considerations"
        />
      </StackItem>

      <StackItem>
        <RulesDisclaimer disclaimer={response.rules_disclaimer} />
      </StackItem>
    </Stack>
  );
}
