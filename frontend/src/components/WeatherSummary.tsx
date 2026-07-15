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
} from "@patternfly/react-core";
import type { WeatherSummary as WeatherSummaryModel } from "../models/packmate";

interface WeatherSummaryProps {
  summary: WeatherSummaryModel;
}

export function WeatherSummary({ summary }: WeatherSummaryProps) {
  return (
    <Card isFullHeight>
      <CardTitle>Weather summary</CardTitle>
      <CardBody>
        <DescriptionList isHorizontal>
          <DescriptionListGroup>
            <DescriptionListTerm>Location</DescriptionListTerm>
            <DescriptionListDescription>{summary.location}</DescriptionListDescription>
          </DescriptionListGroup>
          <DescriptionListGroup>
            <DescriptionListTerm>Overview</DescriptionListTerm>
            <DescriptionListDescription>{summary.overview}</DescriptionListDescription>
          </DescriptionListGroup>
        </DescriptionList>
        <Grid hasGutter style={{ marginTop: "1rem" }}>
          {summary.min_temperature && (
            <GridItem span={12} md={4}>
              <strong>Min:</strong> {summary.min_temperature}
            </GridItem>
          )}
          {summary.max_temperature && (
            <GridItem span={12} md={4}>
              <strong>Max:</strong> {summary.max_temperature}
            </GridItem>
          )}
          {summary.conditions && (
            <GridItem span={12} md={4}>
              <strong>Conditions:</strong> {summary.conditions}
            </GridItem>
          )}
        </Grid>
      </CardBody>
    </Card>
  );
}
