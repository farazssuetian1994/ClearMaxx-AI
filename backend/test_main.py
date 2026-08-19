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


from main import (_normalize_progress, PROGRESS_PROMPT, _language_instruction,
                  _build_analysis_prompt, _normalize_category, ROUTINE_CATEGORIES)


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
    rendered = PROGRESS_PROMPT.format(trends_json="{}", routine_json="[]", language_block="")
    assert "{}" in rendered
    assert "[]" in rendered


def test_language_instruction_is_empty_for_english_and_unknown_codes():
    for code in ("en", "EN", None, "", "xx"):
        assert _language_instruction(code, free_text_fields="a", canonical_fields="b") == ""


def test_language_instruction_names_the_language_and_protects_canonical_fields():
    block = _language_instruction("ja", free_text_fields="summary", canonical_fields='"severity"')
    assert "Japanese" in block
    assert "summary" in block
    assert '"severity"' in block


def test_localized_prompt_protects_routine_category_from_translation():
    """`category` drives the app's routine icon/tint heuristic, which matches on
    English substrings — translating it would silently break those icons."""
    for prompt in (_build_analysis_prompt(None, "ja"), _build_analysis_prompt(None, "es")):
        assert 'always in English' in prompt
        # It must be named as protected, not as translatable prose.
        block = prompt[prompt.index("LANGUAGE (hard requirement)"):]
        assert '"category"' in block
        assert "title/detail/tags" in block
        assert "category/title/detail/tags" not in block


def test_analysis_prompt_is_unchanged_for_english_but_localized_otherwise():
    english = _build_analysis_prompt(None, "en")
    korean = _build_analysis_prompt(None, "ko")
    assert "LANGUAGE (hard requirement)" not in english
    assert "Korean" in korean
    # The canonical identifiers must never be presented as translatable.
    assert "Good/Mild/Moderate/Severe" in korean


def test_normalize_category_passes_through_canonical_values():
    for category in ROUTINE_CATEGORIES:
        assert _normalize_category(category) == category


def test_normalize_category_maps_model_inventions_onto_the_list():
    # Observed in real Vertex responses, plus near-misses worth covering.
    assert _normalize_category("Eye Cream") == "Eye Cream"
    assert _normalize_category("eye serum") == "Eye Cream"     # 'eye' wins over 'serum'
    assert _normalize_category("Gentle Face Wash") == "Cleanser"
    assert _normalize_category("Hydrating Toner") == "Toner"
    assert _normalize_category("Chemical Peel") == "Exfoliant"
    assert _normalize_category("Night Cream") == "Moisturizer"
    assert _normalize_category("SPF 50") == "Sunscreen"
    assert _normalize_category("Sheet Mask") == "Mask"


def test_normalize_category_falls_back_rather_than_leaking_unknown_text():
    """The app can only translate values on the list, so nothing else may pass."""
    for junk in ("", None, "???", "Étape inconnue", "美容液ステップ"):
        assert _normalize_category(junk) in ROUTINE_CATEGORIES


def test_normalize_routine_step_never_emits_an_untranslatable_category():
    from main import _normalize_routine_step
    step = _normalize_routine_step({"time": "PM", "category": "Retinol Booster",
                                    "title": "T", "detail": "D", "tags": []})
    assert step["category"] in ROUTINE_CATEGORIES
