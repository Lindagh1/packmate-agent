from app.models.chat import PackingItem, PackingResponse
from app.models.profile import TravelerProfile
from app.tools.baggage import get_rules_disclaimer, lookup_baggage_rules


def merge_stable_unique(*sources: list[str]) -> list[str]:
    merged: list[str] = []
    for source in sources:
        for value in source:
            if value not in merged:
                merged.append(value)
    return merged


def collect_profile_baggage_warnings(profile: TravelerProfile) -> list[str]:
    """Apply general baggage demo rules when a profile with baggage_type is provided."""
    result = lookup_baggage_rules(
        baggage_type=profile.baggage_type,
        include_general_rules=True,
    )
    return merge_stable_unique(result.warnings, result.general_rules)


def collect_packing_item_warnings(
    packing_items: list[PackingItem],
    baggage_type: str,
) -> list[str]:
    """Analyze packing items deterministically against baggage demo rules."""
    warnings: list[str] = []

    for item in packing_items:
        result = lookup_baggage_rules(
            baggage_type=baggage_type,
            item=item.name,
            category=item.category,
        )
        warnings = merge_stable_unique(warnings, result.warnings)

    return warnings


def filter_sensitive_note_leaks(
    values: list[str],
    profile: TravelerProfile | None,
) -> list[str]:
    if profile is None or not profile.medical_or_accessibility_notes:
        return values

    note_fragments = {note.strip().lower() for note in profile.medical_or_accessibility_notes if note.strip()}
    filtered: list[str] = []

    for value in values:
        normalized = value.strip().lower()
        if any(fragment in normalized or normalized in fragment for fragment in note_fragments):
            continue
        filtered.append(value)

    return filtered


def enrich_packing_response(
    response: PackingResponse,
    profile: TravelerProfile | None,
    collected_baggage_warnings: list[str],
    rules_disclaimer: str | None,
) -> PackingResponse:
    baggage_type = profile.baggage_type if profile is not None else "cabin"

    deterministic_baggage_warnings = merge_stable_unique(
        collected_baggage_warnings,
        collect_packing_item_warnings(response.packing_items, baggage_type),
    )

    deterministic_profile_considerations = profile.derive_sensitive_considerations() if profile else []
    safe_profile_considerations = filter_sensitive_note_leaks(
        response.profile_considerations,
        profile,
    )

    return response.model_copy(
        update={
            "baggage_warnings": deterministic_baggage_warnings,
            "profile_considerations": merge_stable_unique(
                deterministic_profile_considerations,
                safe_profile_considerations,
            ),
            "warnings": filter_sensitive_note_leaks(response.warnings, profile),
            "rules_disclaimer": rules_disclaimer or response.rules_disclaimer or get_rules_disclaimer(),
        }
    )
