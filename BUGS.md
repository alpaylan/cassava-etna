# cassava — Injected Bugs

RFC 4180 CSV parsing/encoding library (haskell-hvr/cassava). Bug fixes mined from upstream history; modern HEAD is the base, each patch reverse-applies a fix to install the original bug.

Total mutations: 4

## Bug Index

| # | Variant | Name | Location | Injection | Fix Commit |
|---|---------|------|----------|-----------|------------|
| 1 | `custom_delim_unescaped` | `escape_uses_literal_comma_not_delim` | `src/Data/Csv/Encoding.hs:295` | `patch` | `8f1abb653b1d3f43e33525e65784b01ecdd27dd5` |
| 2 | `escaped_trailing_quote` | `escapedField_crashes_on_lone_quote` | `src/Data/Csv/Parser.hs:149` | `patch` | `14d401d384d0983aac4336745049b44efc835e34` |
| 3 | `foldl_skips_errors` | `foldlRecords_halts_on_error` | `src/Data/Csv/Streaming.hs:105` | `patch` | `e1de8377e492a9285564dfa9cee84759220d9753` |
| 4 | `foldr_skips_errors` | `foldrRecords_halts_on_error` | `src/Data/Csv/Streaming.hs:97` | `patch` | `6c9127e88be1797be2f54ea1f833d73bab6282bd` |

## Property Mapping

| Variant | Property | Witness(es) |
|---------|----------|-------------|
| `custom_delim_unescaped` | `CustomDelimEscaped` | `witness_custom_delim_escaped_case_semicolon`, `witness_custom_delim_escaped_case_tab` |
| `escaped_trailing_quote` | `EscapedFieldHandlesLoneQuote` | `witness_escaped_field_handles_lone_quote_case_lone_quote`, `witness_escaped_field_handles_lone_quote_case_unbalanced` |
| `foldl_skips_errors` | `FoldlSkipsConversionErrors` | `witness_foldl_skips_conversion_errors_case_left_right`, `witness_foldl_skips_conversion_errors_case_interleaved` |
| `foldr_skips_errors` | `FoldrSkipsConversionErrors` | `witness_foldr_skips_conversion_errors_case_left_right`, `witness_foldr_skips_conversion_errors_case_interleaved` |

## Framework Coverage

| Property | quickcheck | hedgehog | falsify | smallcheck |
|----------|---------:|-------:|------:|---------:|
| `CustomDelimEscaped` | ✓ | ✓ | ✓ | ✓ |
| `EscapedFieldHandlesLoneQuote` | ✓ | ✓ | ✓ | ✓ |
| `FoldlSkipsConversionErrors` | ✓ | ✓ | ✓ | ✓ |
| `FoldrSkipsConversionErrors` | ✓ | ✓ | ✓ | ✓ |

## Bug Details

### 1. escape_uses_literal_comma_not_delim

- **Variant**: `custom_delim_unescaped`
- **Location**: `src/Data/Csv/Encoding.hs:295` (inside `escape`)
- **Property**: `CustomDelimEscaped`
- **Witness(es)**:
  - `witness_custom_delim_escaped_case_semicolon` — delim=`;`, fields=["a;b","c"] must round-trip
  - `witness_custom_delim_escaped_case_tab` — delim=`\t`, fields=["x\ty","z"] must round-trip
- **Source**: internal — Fix bug where custom delimiters weren't escaped
  > encode's escape function decided whether to quote a field by checking for `comma` (literal 0x2C). When the user picked a different `encDelimiter` (tab, semicolon, etc.) and a field contained that delimiter, escape did not quote it — so the delimiter leaked into the encoded output and broke round-tripping. The fix swaps the literal `comma` for the actual `delim` parameter.
- **Fix commit**: `8f1abb653b1d3f43e33525e65784b01ecdd27dd5` — Fix bug where custom delimiters weren't escaped
- **Invariant violated**: Round-trip: decodeWith opts NoHeader (encodeWith opts [fields]) = Right [fields] for any non-empty record whose fields don't contain `\"`/CR/LF, when opts uses a non-comma delimiter that is also a possible field byte.
- **How the mutation triggers**: Reverse-applying the patch swaps `b == delim` for `b == comma` inside `needsQuoting`. Encoding `["a;b", "c"]` with delim=`;` then emits `a;b;c\r\n`, and the decoder splits the first field at `;`.

### 2. escapedField_crashes_on_lone_quote

- **Variant**: `escaped_trailing_quote`
- **Location**: `src/Data/Csv/Parser.hs:149` (inside `escapedField`)
- **Property**: `EscapedFieldHandlesLoneQuote`
- **Witness(es)**:
  - `witness_escaped_field_handles_lone_quote_case_lone_quote` — decode of `\"` must not crash
  - `witness_escaped_field_handles_lone_quote_case_unbalanced` — decode of `\"a` must not crash
- **Source**: internal — fix: handle case when input for field parser is a single opening double-quote
  > escapedField used `S.init <$> A.scan ...` and assumed the scan returned at least one byte. When the input was just a single opening doublequote `"` (or any unbalanced opening), the scan returned `BS.empty`, and `S.init` raised `Prelude.error` for an empty bytestring. The fix checks `S.null` first and uses Parser failure instead.
- **Fix commit**: `14d401d384d0983aac4336745049b44efc835e34` — fix: handle case when input for field parser is a single opening double-quote
- **Invariant violated**: decode of any byte sequence must yield Left or Right; it must never raise an exception. In particular `decode NoHeader "\""` must produce a Left, not crash.
- **How the mutation triggers**: Reverse-applying the patch removes the S.null guard, so the buggy `S.init` is called on an empty bytestring whenever the doublequote-scan consumed nothing — e.g. on input `\"`.

### 3. foldlRecords_halts_on_error

- **Variant**: `foldl_skips_errors`
- **Location**: `src/Data/Csv/Streaming.hs:105` (inside `foldlRecords'`)
- **Property**: `FoldlSkipsConversionErrors`
- **Witness(es)**:
  - `witness_foldl_skips_conversion_errors_case_left_right` — foldl' (flip (:)) [] over [Left, Right 1, Right 2] = [2,1] (then reversed to [1,2])
  - `witness_foldl_skips_conversion_errors_case_interleaved` — Interleaved Left/Right left-folds to the Rights only
- **Source**: internal — Fix #102 for foldl'
  > Same defect as foldrRecords but for foldlRecords' — the Foldable instance for Records was not skipping conversion errors as documented. The fix is symmetric: add the `Cons (Left _) -> go z rs` arm.
- **Fix commit**: `e1de8377e492a9285564dfa9cee84759220d9753` — Fix #102 for foldl'
- **Invariant violated**: F.foldl' f z over Records skips Left items: the strict left fold sees only the Right values, in order.
- **How the mutation triggers**: Reverse-applying the patch deletes the `Cons (Left _)` clause from foldlRecords'. Folding `[Left _, Right 1, Right 2]` accumulates nothing where the Right values should have been observed.

### 4. foldrRecords_halts_on_error

- **Variant**: `foldr_skips_errors`
- **Location**: `src/Data/Csv/Streaming.hs:97` (inside `foldrRecords`)
- **Property**: `FoldrSkipsConversionErrors`
- **Witness(es)**:
  - `witness_foldr_skips_conversion_errors_case_left_right` — Left then two Rights folds to the two Rights
  - `witness_foldr_skips_conversion_errors_case_interleaved` — Interleaved Left/Right folds to the Rights only
- **Source**: internal — Fix #102 for foldr
  > foldrRecords had no `Cons (Left _)` case, so when the stream contained a conversion error the fold halted and trailing Right records were discarded. The Haddock for the Foldable instance promises that records that fail to convert are *skipped*; the fix adds the `Left _ -> go z rs` arm.
- **Fix commit**: `6c9127e88be1797be2f54ea1f833d73bab6282bd` — Fix #102 for foldr
- **Invariant violated**: F.foldr (:) [] (mkRecords xs) = [x | Right x <- xs]: the Foldable instance for Records skips conversion errors instead of stopping at the first one.
- **How the mutation triggers**: Reverse-applying the patch deletes the `Cons (Left _)` clause from foldrRecords. Folding `[Left _, Right 1, Right 2]` then yields `[]` instead of `[1,2]`.
