from app.models.profile import TravelerProfile


def lookup_traveler_profile(profile: TravelerProfile | None) -> dict:
    if profile is None:
        return {
            "available": False,
            "message": "No traveler profile was provided in this request.",
        }

    payload = profile.for_agent()
    payload["available"] = True
    payload["considerations"] = _build_considerations(profile)
    return payload


def _build_considerations(profile: TravelerProfile) -> list[str]:
    considerations: list[str] = []

    if profile.trip_type == "business":
        considerations.append("Business trip: include professional attire and meeting essentials.")
    else:
        considerations.append("Leisure trip: prioritize comfort and activity-specific gear.")

    if profile.activities:
        considerations.append(
            "Activities to plan for: " + ", ".join(profile.activities) + "."
        )

    if profile.clothing_preferences:
        considerations.append(
            "Clothing preferences: " + ", ".join(profile.clothing_preferences) + "."
        )

    if profile.available_items:
        considerations.append(
            "Items already available: " + ", ".join(profile.available_items) + "."
        )

    if profile.medical_or_accessibility_notes:
        considerations.append(
            "Medical or accessibility needs were provided and should influence packing, "
            "but must not be repeated verbatim in the final user-facing response."
        )

    return considerations
