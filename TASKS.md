# cassava — ETNA Tasks

Total tasks: 16

## Task Index

| Task | Variant | Framework | Property | Witness |
|------|---------|-----------|----------|---------|
| 001 | `custom_delim_unescaped` | quickcheck | `CustomDelimEscaped` | `witness_custom_delim_escaped_case_semicolon` |
| 002 | `custom_delim_unescaped` | hedgehog | `CustomDelimEscaped` | `witness_custom_delim_escaped_case_semicolon` |
| 003 | `custom_delim_unescaped` | falsify | `CustomDelimEscaped` | `witness_custom_delim_escaped_case_semicolon` |
| 004 | `custom_delim_unescaped` | smallcheck | `CustomDelimEscaped` | `witness_custom_delim_escaped_case_semicolon` |
| 005 | `escaped_trailing_quote` | quickcheck | `EscapedFieldHandlesLoneQuote` | `witness_escaped_field_handles_lone_quote_case_lone_quote` |
| 006 | `escaped_trailing_quote` | hedgehog | `EscapedFieldHandlesLoneQuote` | `witness_escaped_field_handles_lone_quote_case_lone_quote` |
| 007 | `escaped_trailing_quote` | falsify | `EscapedFieldHandlesLoneQuote` | `witness_escaped_field_handles_lone_quote_case_lone_quote` |
| 008 | `escaped_trailing_quote` | smallcheck | `EscapedFieldHandlesLoneQuote` | `witness_escaped_field_handles_lone_quote_case_lone_quote` |
| 009 | `foldl_skips_errors` | quickcheck | `FoldlSkipsConversionErrors` | `witness_foldl_skips_conversion_errors_case_left_right` |
| 010 | `foldl_skips_errors` | hedgehog | `FoldlSkipsConversionErrors` | `witness_foldl_skips_conversion_errors_case_left_right` |
| 011 | `foldl_skips_errors` | falsify | `FoldlSkipsConversionErrors` | `witness_foldl_skips_conversion_errors_case_left_right` |
| 012 | `foldl_skips_errors` | smallcheck | `FoldlSkipsConversionErrors` | `witness_foldl_skips_conversion_errors_case_left_right` |
| 013 | `foldr_skips_errors` | quickcheck | `FoldrSkipsConversionErrors` | `witness_foldr_skips_conversion_errors_case_left_right` |
| 014 | `foldr_skips_errors` | hedgehog | `FoldrSkipsConversionErrors` | `witness_foldr_skips_conversion_errors_case_left_right` |
| 015 | `foldr_skips_errors` | falsify | `FoldrSkipsConversionErrors` | `witness_foldr_skips_conversion_errors_case_left_right` |
| 016 | `foldr_skips_errors` | smallcheck | `FoldrSkipsConversionErrors` | `witness_foldr_skips_conversion_errors_case_left_right` |

## Witness Catalog

- `witness_custom_delim_escaped_case_semicolon` — delim=`;`, fields=["a;b","c"] must round-trip
- `witness_custom_delim_escaped_case_tab` — delim=`\t`, fields=["x\ty","z"] must round-trip
- `witness_escaped_field_handles_lone_quote_case_lone_quote` — decode of `\"` must not crash
- `witness_escaped_field_handles_lone_quote_case_unbalanced` — decode of `\"a` must not crash
- `witness_foldl_skips_conversion_errors_case_left_right` — foldl' (flip (:)) [] over [Left, Right 1, Right 2] = [2,1] (then reversed to [1,2])
- `witness_foldl_skips_conversion_errors_case_interleaved` — Interleaved Left/Right left-folds to the Rights only
- `witness_foldr_skips_conversion_errors_case_left_right` — Left then two Rights folds to the two Rights
- `witness_foldr_skips_conversion_errors_case_interleaved` — Interleaved Left/Right folds to the Rights only
