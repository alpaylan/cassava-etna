{-# LANGUAGE OverloadedStrings #-}
module Etna.Witnesses where

import qualified Data.ByteString as BS

import Etna.Properties
import Etna.Result

-- | A single double-quote, the canonical buggy input from #222.
witness_escaped_field_handles_lone_quote_case_lone_quote :: PropertyResult
witness_escaped_field_handles_lone_quote_case_lone_quote =
  property_escaped_field_handles_lone_quote
    (LoneQuoteArgs (BS.pack [0x22]))

-- | "\"a" — opening quote, content, no closing. Also drops into the
-- empty-scan branch because the unbalanced quote leaves nothing to
-- 'init'.
witness_escaped_field_handles_lone_quote_case_unbalanced :: PropertyResult
witness_escaped_field_handles_lone_quote_case_unbalanced =
  property_escaped_field_handles_lone_quote
    (LoneQuoteArgs (BS.pack [0x22, 0x61]))

------------------------------------------------------------------------------
-- foldr / foldl' over Records: Left-then-Right must yield the Right value.

witness_foldr_skips_conversion_errors_case_left_right :: PropertyResult
witness_foldr_skips_conversion_errors_case_left_right =
  property_foldr_skips_conversion_errors
    (RecordsArgs [Left "boom", Right 1, Right 2])

witness_foldr_skips_conversion_errors_case_interleaved :: PropertyResult
witness_foldr_skips_conversion_errors_case_interleaved =
  property_foldr_skips_conversion_errors
    (RecordsArgs [Right 1, Left "x", Right 2, Left "y", Right 3])

witness_foldl_skips_conversion_errors_case_left_right :: PropertyResult
witness_foldl_skips_conversion_errors_case_left_right =
  property_foldl_skips_conversion_errors
    (RecordsArgs [Left "boom", Right 1, Right 2])

witness_foldl_skips_conversion_errors_case_interleaved :: PropertyResult
witness_foldl_skips_conversion_errors_case_interleaved =
  property_foldl_skips_conversion_errors
    (RecordsArgs [Right 1, Left "x", Right 2, Left "y", Right 3])

------------------------------------------------------------------------------
-- Custom-delim escape: a field containing the chosen delimiter must be
-- quoted on encode so the round-trip recovers the original.

-- Semicolon delimiter, field "a;b".
witness_custom_delim_escaped_case_semicolon :: PropertyResult
witness_custom_delim_escaped_case_semicolon =
  property_custom_delim_escaped
    (CustomDelimArgs 0x3B [BS.pack [0x61, 0x3B, 0x62], BS.pack [0x63]])

-- Tab delimiter, field "x\ty".
witness_custom_delim_escaped_case_tab :: PropertyResult
witness_custom_delim_escaped_case_tab =
  property_custom_delim_escaped
    (CustomDelimArgs 0x09 [BS.pack [0x78, 0x09, 0x79], BS.pack [0x7A]])
