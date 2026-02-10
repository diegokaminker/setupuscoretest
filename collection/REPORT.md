# FHIR Setup Scripts – Execution Report

**Date:** 2026-02-05  
**Total scripts:** 46 (req_044, req_045, req_047 excluded)  
**Duration:** ~48 seconds

---

## Summary

| Status   | Count |
|----------|-------|
| Success  | 41    |
| Failed   | 5     |

---

## Successful Scripts (41)

| ID          | HTTP |
|-------------|------|
| L00_1_T01   | 200  |
| L00_1_T03   | 200  |
| L01_1_T01   | 200  |
| L01_1_T02   | 200  |
| L01_1_T04   | 200  |
| L01_1_T05   | 200  |
| L01_1_T06   | 200  |
| L01_2_T01   | 200  |
| L01_2_T02   | 200  |
| L01_3_T01   | 200  |
| L01_3_T02   | 200  |
| L01_3_T03   | 200  |
| L01_3_T04   | 200  |
| L02_1_T01   | 200  |
| L02_1_T02   | 200  |
| L02_1_T03   | 200  |
| L02_1_T04   | 200  |
| L02_1_T05   | 200  |
| L03_1_T01   | 200  |
| L03_1_T02   | 200  |
| L03_1_T03   | 200  |
| L03_1_T04   | 200  |
| L03_2_T01   | 200  |
| L03_2_T02   | 200  |
| L03_2_T03   | 200  |
| L03_2_T04   | 200  |
| L03_3_T01   | 200  |
| L03_3_T02   | 200  |
| L03_3_T03   | 200  |
| req_036     | 200  |
| L04_1_T01   | 200  |
| L04_1_T02   | 200  |
| L04_2_T01   | 200  |
| L04_2_T02   | 200  |
| req_046     | 201  |
| req_048     | 201  |

---

## Failed Scripts (5)

### 1. L00_1_T02 — HTTP 412
- **Cause:** Precondition failed – search matched 2 resources
- **Error:** "HAPI-0958: Failed to CREATE Patient with match URL because this search matched 2 resources"
- **Note:** Duplicate data in server; not a conversion issue

### 2. L00_1_T04 — HTTP 422
- **Cause:** Profile validation
- **Error:** VALIDATION_VAL_PROFILE_UNKNOWN_NOT_POLICY
- **Note:** Server rejects an unknown profile reference (regeneration may have overwritten prior fix)

### 3. L01_1_T03 — HTTP 400
- **Cause:** Body sent as XML instead of JSON
- **Error:** "Content does not appear to be FHIR JSON, first non-whitespace character was: '<' (must be '{')"
- **Fix:** Ensure XML→JSON conversion (or keep manual JSON; regeneration overwrites)

### 4. L01_3_T05 — HTTP 422
- **Cause:** `text.div` must be a simple value, not an Object
- **Error:** "This property must be a simple value, not an Object (div at Bundle.entry[2].resource.text.div)"
- **Fix:** Unwrap div when it is an object (e.g. `{value: "x"}` → `"<div>...</div>"`)

### 5. L03_3_T04 — HTTP 422
- **Cause:** Terminology_PassThrough_TX_Message, XHTML fragment resolution
- **Error:** Practitioner qualification code validation; Condition text.div hyperlink does not resolve; LOINC category validation

---

## Excluded Scripts (not run)

| ID      | Reason                        |
|---------|-------------------------------|
| req_047 | Not needed                    |
| req_044 | Terminology validation issues |
| req_045 | Terminology validation issues |

---

## Error Categories

| Category                    | Count | Scripts      |
|-----------------------------|-------|--------------|
| Duplicate / precondition    | 1     | L00_1_T02    |
| Profile validation          | 1     | L00_1_T04    |
| Wrong content type (XML)    | 1     | L01_1_T03    |
| text.div as object          | 1     | L01_3_T05    |
| Terminology / validation    | 1     | L03_3_T04    |

---

## Recommended Fixes

1. **L01_1_T03:** Add XML→JSON conversion for requests with no Content-Type but XML body (e.g. check `body.options.raw.language === "xml"` or body starts with `<`).
2. **L01_3_T05:** Fix div unwrapping when `text.div` is `{value: "x"}` – ensure it becomes xhtml string.
3. **L00_1_T04:** Restore US Core profile and display text if regeneration overwrote prior fix.
4. **L00_1_T02:** Server-side: resolve duplicate Patient resources for identifier L00_1_T02.
5. **L03_3_T04:** Terminology / XHTML issues; may need manual edits or exclusion.
