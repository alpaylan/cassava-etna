module Etna.Gens.QuickCheck where

import qualified Data.ByteString as BS
import           Data.Word       (Word8)
import qualified Test.QuickCheck as QC

import Etna.Properties (LoneQuoteArgs(..), RecordsArgs(..),
                        CustomDelimArgs(..))

-- | Bytes drawn mostly from a small printable ASCII pool, with a
-- frequently-emitted double-quote so 'escapedField' is repeatedly
-- entered and the lone-quote pathology is reachable.
gen_escaped_field_handles_lone_quote :: QC.Gen LoneQuoteArgs
gen_escaped_field_handles_lone_quote = do
  len <- QC.choose (0, 6)
  bytes <- QC.vectorOf len (QC.frequency
              [ (4, QC.elements (map fromIntegral [0x61..0x6A] :: [Word8]))
              , (5, pure (0x22 :: Word8))
              , (1, pure (0x2C :: Word8))
              , (1, pure (0x0A :: Word8))
              ])
  pure (LoneQuoteArgs (BS.pack bytes))

gen_foldr_skips_conversion_errors :: QC.Gen RecordsArgs
gen_foldr_skips_conversion_errors = RecordsArgs <$> genItems

gen_foldl_skips_conversion_errors :: QC.Gen RecordsArgs
gen_foldl_skips_conversion_errors = RecordsArgs <$> genItems

genItems :: QC.Gen [Either String Int]
genItems = do
  n <- QC.choose (1, 6)
  QC.vectorOf n $ QC.frequency
    [ (1, Left  <$> QC.elements ["e1", "e2", "e3"])
    , (3, Right <$> QC.choose (0 :: Int, 100))
    ]

gen_custom_delim_escaped :: QC.Gen CustomDelimArgs
gen_custom_delim_escaped = do
  delim <- QC.elements (map fromIntegral [0x09, 0x3B, 0x7C, 0x3A] :: [Word8])
  nFields <- QC.choose (1, 3)
  fields <- QC.vectorOf nFields (genField delim)
  pure (CustomDelimArgs delim fields)
  where
    genField :: Word8 -> QC.Gen BS.ByteString
    genField delim = do
      flen <- QC.choose (0, 5)
      bytes <- QC.vectorOf flen (QC.frequency
        [ (4, QC.elements (map fromIntegral [0x61..0x68] :: [Word8]))
        , (3, pure delim)
        , (1, pure 0x20)
        ])
      pure (BS.pack bytes)
