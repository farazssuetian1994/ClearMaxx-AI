import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from main import _normalize, METRICS


def _full_metric(name):
    return {
        "name": name, "value": 50, "severity": "Mild",
        "summary": "test", "ingredients": ["A"], "tips": ["B"],
    }


def _base_parsed(**overrides):
    parsed = {
        "clearScore": 80, "confidence": 90, "skinType": "Normal", "summary": "ok",
        "metrics": [_full_metric(m) for m in METRICS],
    }
    parsed.update(overrides)
    return parsed


def test_normalize_routine_steps_valid_passthrough():
    parsed = _base_parsed(routineSteps=[
        {"time": "AM", "category": "Cleanser", "title": "Foam Wash",
         "detail": "Cleanses gently.", "tags": ["Fragrance-free"]},
        {"time": "PM", "category": "Treatment", "title": "Retinol Serum",
         "detail": "Renews overnight.", "tags": []},
    ])
    result = _normalize(parsed)
    assert result["routineSteps"] == [
        {"time": "AM", "category": "Cleanser", "title": "Foam Wash",
         "detail": "Cleanses gently.", "tags": ["Fragrance-free"]},
        {"time": "PM", "category": "Treatment", "title": "Retinol Serum",
         "detail": "Renews overnight.", "tags": []},
    ]


def test_normalize_routine_steps_missing_key_defaults_empty():
    result = _normalize(_base_parsed())
    assert result["routineSteps"] == []


def test_normalize_routine_steps_invalid_time_defaults_to_am():
    parsed = _base_parsed(routineSteps=[
        {"time": "Evening", "category": "Cleanser", "title": "X", "detail": "Y", "tags": []},
    ])
    result = _normalize(parsed)
    assert result["routineSteps"][0]["time"] == "AM"


def test_normalize_routine_steps_caps_tags_and_step_count():
    one_step = {"time": "AM", "category": "C", "title": "T", "detail": "D",
                "tags": ["a", "b", "c", "d", "e"]}
    parsed = _base_parsed(routineSteps=[one_step] * 10)
    result = _normalize(parsed)
    assert len(result["routineSteps"]) == 8
    assert len(result["routineSteps"][0]["tags"]) == 3


def test_normalize_routine_steps_ignores_non_dict_items():
    parsed = _base_parsed(routineSteps=[
        "just a string",
        {"time": "PM", "category": "C", "title": "T", "detail": "D", "tags": []},
    ])
    result = _normalize(parsed)
    assert len(result["routineSteps"]) == 1
    assert result["routineSteps"][0]["time"] == "PM"


from main import _normalize_progress, PROGRESS_PROMPT


def test_normalize_progress_valid_passthrough():
    parsed = {
        "verdict": "improving",
        "headline": "Great progress",
        "narrative": "Your acne cleared up.",
        "updatedRoutine": [
            {"time": "AM", "category": "Cleanser", "title": "Foam Wash",
             "detail": "Cleanses gently.", "tags": ["Fragrance-free"]},
        ],
    }
    trends = [
        {"name": "Acne", "first_value": 55, "latest_value": 30, "direction": "better"},
        {"name": "Dark Spots", "first_value": 48, "latest_value": 47, "direction": "flat"},
    ]
    result = _normalize_progress(parsed, trends)
    assert result["verdict"] == "improving"
    assert result["working"] == ["Acne"]
    assert result["stalled"] == ["Dark Spots"]
    assert result["updatedRoutine"][0]["title"] == "Foam Wash"


def test_normalize_progress_invalid_verdict_defaults_to_steady():
    parsed = {"verdict": "amazing!!"}
    result = _normalize_progress(parsed, trends=[])
    assert result["verdict"] == "steady"


def test_normalize_progress_derives_buckets_from_trends_not_model_output():
    # Model tries to claim Acne is "watch" even though the given trend direction
    # is "better" — normalize must ignore the model's own bucketing entirely.
    parsed = {"verdict": "steady", "working": [], "stalled": [], "watch": ["Acne"]}
    trends = [{"name": "Acne", "first_value": 55, "latest_value": 30, "direction": "better"}]
    result = _normalize_progress(parsed, trends)
    assert result["working"] == ["Acne"]
    assert result["watch"] == []


def test_normalize_progress_caps_updated_routine_at_eight():
    one_step = {"time": "AM", "category": "C", "title": "T", "detail": "D", "tags": []}
    parsed = {"verdict": "steady", "updatedRoutine": [one_step] * 10}
    result = _normalize_progress(parsed, trends=[])
    assert len(result["updatedRoutine"]) == 8


def test_progress_prompt_has_trends_and_routine_placeholders():
    rendered = PROGRESS_PROMPT.format(trends_json="{}", routine_json="[]")
    assert "{}" in rendered
    assert "[]" in rendered
