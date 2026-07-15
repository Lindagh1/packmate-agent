from dataclasses import dataclass, field

from app.models.profile import TravelerProfile


@dataclass
class ToolContext:
    traveler_profile: TravelerProfile | None = None
    collected_baggage_warnings: list[str] = field(default_factory=list)
    rules_disclaimer: str | None = None

    def record_baggage_result(self, warnings: list[str], disclaimer: str) -> None:
        for warning in warnings:
            if warning not in self.collected_baggage_warnings:
                self.collected_baggage_warnings.append(warning)
        self.rules_disclaimer = disclaimer
