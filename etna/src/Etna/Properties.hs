{-# LANGUAGE OverloadedStrings #-}
module Etna.Properties where

import qualified Data.ByteString          as BS
import qualified Data.ByteString.Lazy     as BL
import qualified Data.Vector              as V
import           Data.Word                (Word8)

import           Data.Csv                 (HasHeader(..), decode, decodeWith,
                                           encodeWith, defaultDecodeOptions,
                                           defaultEncodeOptions, decDelimiter,
                                           encDelimiter)
import qualified Data.Csv.Streaming       as S
import qualified Data.Foldable            as F

import           Etna.Result

------------------------------------------------------------------------------
-- Variant 1: escaped_trailing_quote
-- "fix: handle case when input for field parser is a single opening
-- double-quote" (sha 14d401d3)
--
-- Pre-fix: escapedField calls 'S.init' eagerly on the result of 'A.scan';
-- when the scan returns an empty ByteString (e.g. input is a lone @"@),
-- 'S.init' raises an exception. The fixed version checks 'S.null' first
-- and uses Parser failure instead.
------------------------------------------------------------------------------

newtype LoneQuoteArgs = LoneQuoteArgs { lqInput :: BS.ByteString }
  deriving (Show, Eq)

-- | Property: decoding any byte sequence must produce either 'Left' (a
-- parser error) or 'Right' (a result vector). It must never raise an
-- exception. The buggy 'escapedField' raises @ByteString.init: empty@
-- on @"@-only fragments; we capture that as @Fail@ in the runner via
-- 'try'.
property_escaped_field_handles_lone_quote :: LoneQuoteArgs -> PropertyResult
property_escaped_field_handles_lone_quote (LoneQuoteArgs bs) =
  let lazy = BL.fromStrict bs
      result = decode NoHeader lazy
                :: Either String (V.Vector (V.Vector BS.ByteString))
  in case result of
       Left _  -> Pass
       Right v -> v `seq` Pass

------------------------------------------------------------------------------
-- Variant 2: foldr_skips_errors
-- "Fix #102 for foldr" (sha 6c9127e8)
--
-- Pre-fix: 'foldrRecords' has no 'Cons (Left _)' case, so a conversion
-- error halts the fold and trailing 'Right' records are discarded.
-- The doc says the 'Foldable' instance "skips records that failed to
-- convert"; the fixed version restores that behaviour.
------------------------------------------------------------------------------

-- | Sequence of stream items used as a synthetic 'S.Records'.
newtype RecordsArgs = RecordsArgs { raItems :: [Either String Int] }
  deriving (Show, Eq)

mkRecords :: [Either String Int] -> S.Records Int
mkRecords []     = S.Nil Nothing BL.empty
mkRecords (x:xs) = S.Cons x (mkRecords xs)

property_foldr_skips_conversion_errors :: RecordsArgs -> PropertyResult
property_foldr_skips_conversion_errors (RecordsArgs items) =
  let recs = mkRecords items
      rights = [x | Right x <- items]
      got = F.foldr (:) [] recs
  in if got == rights
       then Pass
       else Fail $ "F.foldr (:) [] " ++ show items ++ " = " ++ show got
                ++ "; expected " ++ show rights

------------------------------------------------------------------------------
-- Variant 3: foldl_skips_errors
-- "Fix #102 for foldl'" (sha e1de8377)
------------------------------------------------------------------------------

property_foldl_skips_conversion_errors :: RecordsArgs -> PropertyResult
property_foldl_skips_conversion_errors (RecordsArgs items) =
  let recs = mkRecords items
      rights = [x | Right x <- items]
      got = reverse (F.foldl' (flip (:)) [] recs)
  in if got == rights
       then Pass
       else Fail $ "F.foldl' " ++ show items ++ " = " ++ show got
                ++ "; expected " ++ show rights

------------------------------------------------------------------------------
-- Variant 4: custom_delim_unescaped
-- "Fix bug where custom delimiters weren't escaped" (sha 8f1abb65)
--
-- Pre-fix: 'escape' only quotes a field when it contains the comma
-- (hard-coded), even when 'encDelimiter' is something else. Encoding a
-- field that contains the chosen non-comma delimiter therefore emits
-- the delimiter raw and breaks round-tripping.
------------------------------------------------------------------------------

data CustomDelimArgs = CustomDelimArgs
  { cdDelim  :: !Word8
  , cdRecord :: ![BS.ByteString]
  } deriving (Show, Eq)

-- Allowed alternative delimiters: tab, semicolon, pipe, colon. We keep
-- this set conservative so 'encodeWith' / 'decodeWith' both accept it
-- (the underlying 'validDelim' rejects @"@, @\\r@, @\\n@).
validDelimByte :: Word8 -> Bool
validDelimByte w = w `elem` [9, 32, 33, 35, 36, 37, 38, 39, 40, 41,
                             42, 43, 45, 46, 47, 58, 59, 60, 61,
                             62, 63, 64, 91, 92, 93, 94, 95, 96,
                             123, 124, 125, 126]

property_custom_delim_escaped :: CustomDelimArgs -> PropertyResult
property_custom_delim_escaped (CustomDelimArgs delim fields)
  | not (validDelimByte delim) = Discard
  | null fields                = Discard
  | all BS.null fields         = Discard  -- blank lines are stripped on decode
  | any badField fields        = Discard
  | otherwise =
      let encOpts = defaultEncodeOptions { encDelimiter = delim }
          decOpts = defaultDecodeOptions { decDelimiter = delim }
          encoded = encodeWith encOpts [fields]
          decoded = decodeWith decOpts NoHeader encoded
                      :: Either String (V.Vector (V.Vector BS.ByteString))
      in case decoded of
           Left err -> Fail $ "decodeWith failed: " ++ err
                          ++ "; encoded = " ++ show encoded
           Right v  ->
             case V.toList <$> V.toList v of
               [row] | row == fields -> Pass
                     | otherwise     -> Fail $ "round-trip mismatch: "
                                            ++ show fields ++ " -> "
                                            ++ show encoded ++ " -> "
                                            ++ show row
               rows -> Fail $ "expected 1 row, got " ++ show (length rows)
                           ++ " from " ++ show encoded
  where
    -- Reject fields whose bytes contain @"@/CR/LF: those make the
    -- round-trip non-trivial in ways unrelated to this bug.
    badField bs = BS.any (\b -> b == 34 || b == 13 || b == 10) bs
