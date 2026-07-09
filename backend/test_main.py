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
