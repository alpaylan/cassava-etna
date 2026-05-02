module Etna.Gens.Hedgehog where

import qualified Data.ByteString as BS
import           Data.Word       (Word8)
import           Hedgehog        (Gen)
import qualified Hedgehog.Gen    as Gen
import qualified Hedgehog.Range  as Range

import Etna.Properties (LoneQuoteArgs(..), RecordsArgs(..),
                        CustomDelimArgs(..))

gen_escaped_field_handles_lone_quote :: Gen LoneQuoteArgs
gen_escaped_field_handles_lone_quote = do
  bytes <- Gen.list (Range.linear 0 6) $ Gen.frequency
              [ (4, Gen.element (map fromIntegral [0x61..0x6A] :: [Word8]))
              , (5, pure (0x22 :: Word8))
              , (1, pure (0x2C :: Word8))
              , (1, pure (0x0A :: Word8))
              ]
  pure (LoneQuoteArgs (BS.pack bytes))

gen_foldr_skips_conversion_errors :: Gen RecordsArgs
gen_foldr_skips_conversion_errors = RecordsArgs <$> genItems

gen_foldl_skips_conversion_errors :: Gen RecordsArgs
gen_foldl_skips_conversion_errors = RecordsArgs <$> genItems

genItems :: Gen [Either String Int]
genItems = Gen.list (Range.linear 1 6) $ Gen.frequency
  [ (1, Left  <$> Gen.element ["e1", "e2", "e3"])
  , (3, Right <$> Gen.int (Range.linear 0 100))
  ]

gen_custom_delim_escaped :: Gen CustomDelimArgs
gen_custom_delim_escaped = do
  delim <- Gen.element (map fromIntegral [0x09, 0x3B, 0x7C, 0x3A] :: [Word8])
  fields <- Gen.list (Range.linear 1 3) (genField delim)
  pure (CustomDelimArgs delim fields)
  where
    genField :: Word8 -> Gen BS.ByteString
    genField delim = do
      bytes <- Gen.list (Range.linear 0 5) $ Gen.frequency
        [ (4, Gen.element (map fromIntegral [0x61..0x68] :: [Word8]))
        , (3, pure delim)
        , (1, pure 0x20)
        ]
      pure (BS.pack bytes)
