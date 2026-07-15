from app.models.profile import TravelerProfile
from app.tools.traveler_profile import lookup_traveler_profile


def test_business_profile_considerations() -> None:
    profile = TravelerProfile(
        trip_type="business",
        baggage_type="cabin",
        activities=["client meetings"],
        clothing_preferences=["formal"],
    )

    result = lookup_traveler_profile(profile)

    assert result["available"] is True
    assert result["trip_type"] == "business"
    assert any("business" in item.lower() for item in result["considerations"])


def test_leisure_profile_with_activities() -> None:
    profile = TravelerProfile(
        trip_type="leisure",
        baggage_type="both",
        activities=["hiking", "swimming"],
        clothing_preferences=["sportswear"],
        available_items=["running shoes"],
    )

    result = lookup_traveler_profile(profile)

    assert result["available"] is True
    assert "hiking" in result["considerations"][1]
    assert any("running shoes" in item for item in result["considerations"])


def test_absent_profile_returns_unavailable() -> None:
    result = lookup_traveler_profile(None)

    assert result["available"] is False
    assert "No traveler profile" in result["message"]


def test_profile_for_logging_hides_medical_notes() -> None:
    profile = TravelerProfile(
        trip_type="leisure",
        baggage_type="cabin",
        activities=["walking"],
        clothing_preferences=["casual"],
        medical_or_accessibility_notes=["Requires wheelchair assistance"],
    )

    logged = profile.for_logging()

    assert "medical_or_accessibility_notes" not in logged
    assert logged["has_medical_or_accessibility_notes"] is True
    assert "wheelchair" not in str(logged)


def test_profile_for_agent_includes_medical_notes_for_llm() -> None:
    profile = TravelerProfile(
        trip_type="leisure",
        baggage_type="cabin",
        activities=["walking"],
        clothing_preferences=["casual"],
        medical_or_accessibility_notes=["Requires wheelchair assistance"],
    )

    agent_view = profile.for_agent()

    assert agent_view["medical_or_accessibility_notes"] == ["Requires wheelchair assistance"]
