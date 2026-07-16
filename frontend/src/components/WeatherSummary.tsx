import type { WeatherSummary as WeatherSummaryModel } from "../models/packmate";

interface WeatherSummaryProps {
  summary: WeatherSummaryModel;
}

export function WeatherSummary({ summary }: WeatherSummaryProps) {
  return (
    <dl className="lab-weather-grid">
      <div>
        <dt>Location</dt>
        <dd>{summary.location}</dd>
      </div>
      <div>
        <dt>Overview</dt>
        <dd>{summary.overview}</dd>
      </div>
      {summary.min_temperature && (
        <div>
          <dt>Min temperature</dt>
          <dd>{summary.min_temperature}</dd>
        </div>
      )}
      {summary.max_temperature && (
        <div>
          <dt>Max temperature</dt>
          <dd>{summary.max_temperature}</dd>
        </div>
      )}
      {summary.conditions && (
        <div>
          <dt>Conditions</dt>
          <dd>{summary.conditions}</dd>
        </div>
      )}
    </dl>
  );
}
