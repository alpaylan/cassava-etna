{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Etna.Gens.SmallCheck where

import qualified Data.ByteString             as BS
import           Data.Word                   (Word8)
import qualified Test.SmallCheck.Series      as SC

import Etna.Properties (LoneQuoteArgs(..), RecordsArgs(..),
                        CustomDelimArgs(..))

-- Bytes drawn from a small bug-relevant pool (lots of '"' and a couple
-- of regular letters); SmallCheck picks the depth-N prefix.
pickByte :: Monad m => SC.Series m Word8
pickByte = SC.generate (\d -> take (max 1 (min d 4))
                                   [0x22, 0x61, 0x2C, 0x0A])

series_escaped_field_handles_lone_quote :: Monad m => SC.Series m LoneQuoteArgs
series_escaped_field_handles_lone_quote = do
  len <- SC.generate (\d -> [0 .. min d 3])
  bytes <- replicateA len pickByte
  pure (LoneQuoteArgs (BS.pack bytes))

series_foldr_skips_conversion_errors :: Monad m => SC.Series m RecordsArgs
series_foldr_skips_conversion_errors = RecordsArgs <$> seriesItems

series_foldl_skips_conversion_errors :: Monad m => SC.Series m RecordsArgs
series_foldl_skips_conversion_errors = RecordsArgs <$> seriesItems

seriesItems :: Monad m => SC.Series m [Either String Int]
seriesItems = do
  len <- SC.generate (\d -> [1 .. min (d + 1) 3])
  replicateA len item
  where
    item :: Monad m => SC.Series m (Either String Int)
    item = do
      side <- SC.generate (\_ -> [0 :: Int, 1])
      if side == 0
        then pure (Left "e")
        else Right <$> SC.generate (\d -> [0 .. min d 2])

-- Custom-delim variant: pick a small set of allowed delimiters and
-- short fields drawn from that delimiter ∪ a letter.
series_custom_delim_escaped :: Monad m => SC.Series m CustomDelimArgs
series_custom_delim_escaped = do
  delim <- SC.generate (\_ -> [0x3B :: Word8, 0x09])
  nFields <- SC.generate (\d -> [1 .. min (d + 1) 2])
  fields <- replicateA nFields (genField delim)
  pure (CustomDelimArgs delim fields)
  where
    genField :: Monad m => Word8 -> SC.Series m BS.ByteString
    genField delim = do
      flen <- SC.generate (\d -> [0 .. min d 3])
      bytes <- replicateA flen (SC.generate (\_ -> [delim, 0x61]))
      pure (BS.pack bytes)

replicateA :: Applicative f => Int -> f a -> f [a]
replicateA 0 _ = pure []
replicateA n f = (:) <$> f <*> replicateA (n - 1) f
