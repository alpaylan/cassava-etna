module Etna.Gens.Falsify where

import qualified Data.ByteString          as BS
import           Data.List.NonEmpty       (NonEmpty(..))
import           Data.Word                (Word8)
import qualified Test.Falsify.Generator   as F
import qualified Test.Falsify.Range       as FR

import Etna.Properties (LoneQuoteArgs(..), RecordsArgs(..),
                        CustomDelimArgs(..))

ne :: [a] -> NonEmpty a
ne []     = error "Etna.Gens.Falsify.ne: empty list"
ne (x:xs) = x :| xs

byteFreq :: [(Word, Word8)] -> F.Gen Word8
byteFreq weighted =
  F.elem (ne (concatMap (\(w, b) -> replicate (fromIntegral w) b) weighted))

gen_escaped_field_handles_lone_quote :: F.Gen LoneQuoteArgs
gen_escaped_field_handles_lone_quote = do
  let pool = concat
        [ replicate 1 (0x22 :: Word8)  -- '"'
        , replicate 1 (0x22 :: Word8)
        , replicate 1 (0x22 :: Word8)
        , replicate 1 (0x22 :: Word8)
        , replicate 1 (0x22 :: Word8)
        , replicate 1 (0x2C :: Word8)
        , replicate 1 (0x0A :: Word8)
        ] ++ map fromIntegral [0x61..0x6A]
  bytes <- F.list (FR.between (0 :: Word, 6)) (F.elem (ne pool))
  pure (LoneQuoteArgs (BS.pack bytes))

gen_foldr_skips_conversion_errors :: F.Gen RecordsArgs
gen_foldr_skips_conversion_errors = RecordsArgs <$> genItems

gen_foldl_skips_conversion_errors :: F.Gen RecordsArgs
gen_foldl_skips_conversion_errors = RecordsArgs <$> genItems

genItems :: F.Gen [Either String Int]
genItems = F.list (FR.between (1 :: Word, 6)) genItem
  where
    genItem :: F.Gen (Either String Int)
    genItem = do
      bit <- F.inRange (FR.between (0 :: Int, 3))
      if bit == 0
        then Left  <$> F.elem (ne ["e1", "e2", "e3"])
        else Right <$> F.inRange (FR.between (0 :: Int, 100))

gen_custom_delim_escaped :: F.Gen CustomDelimArgs
gen_custom_delim_escaped = do
  delim <- F.elem (ne (map fromIntegral [0x09, 0x3B, 0x7C, 0x3A] :: [Word8]))
  fields <- F.list (FR.between (1 :: Word, 3)) (genField delim)
  pure (CustomDelimArgs delim fields)
  where
    genField :: Word8 -> F.Gen BS.ByteString
    genField delim = do
      let pool = delim : delim : delim : 0x20 :
                 map fromIntegral [0x61..0x68]
      bytes <- F.list (FR.between (0 :: Word, 5)) (F.elem (ne pool))
      pure (BS.pack bytes)
