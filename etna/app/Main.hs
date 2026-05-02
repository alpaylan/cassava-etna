{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import           Control.Exception     (SomeException, try)
import           Data.IORef            (newIORef, readIORef, modifyIORef')
import           Data.Time.Clock       (diffUTCTime, getCurrentTime)
import           System.Environment    (getArgs)
import           System.Exit           (exitWith, ExitCode(..))
import           System.IO             (hFlush, stdout)
import           Text.Printf           (printf)

import           Etna.Result           (PropertyResult(..))
import qualified Etna.Properties       as P
import qualified Etna.Witnesses        as W
import qualified Etna.Gens.QuickCheck  as GQ
import qualified Etna.Gens.Hedgehog    as GH
import qualified Etna.Gens.Falsify     as GF
import qualified Etna.Gens.SmallCheck  as GS

import qualified Test.QuickCheck                    as QC
import qualified Hedgehog                           as HH
import qualified Test.Falsify.Generator             as FG
import qualified Test.Falsify.Interactive           as FI
import qualified Test.Falsify.Property              as FP
import qualified Test.SmallCheck                    as SC
import qualified Test.SmallCheck.Drivers            as SCD
import qualified Test.SmallCheck.Series             as SCS

allProperties :: [String]
allProperties =
  [ "EscapedFieldHandlesLoneQuote"
  , "FoldrSkipsConversionErrors"
  , "FoldlSkipsConversionErrors"
  , "CustomDelimEscaped"
  ]

data Outcome = Outcome
  { oStatus :: String
  , oTests  :: Int
  , oCex    :: Maybe String
  , oErr    :: Maybe String
  }

main :: IO ()
main = do
  argv <- getArgs
  case argv of
    [tool, prop] -> dispatch tool prop
    _            -> do
      putStrLn "{\"status\":\"aborted\",\"error\":\"usage: etna-runner <tool> <property>\"}"
      hFlush stdout
      exitWith (ExitFailure 2)

dispatch :: String -> String -> IO ()
dispatch tool prop
  | prop /= "All" && prop `notElem` allProperties =
      emit tool prop "aborted" 0 0 Nothing (Just $ "unknown property: " ++ prop)
  | otherwise = do
      let targets = if prop == "All" then allProperties else [prop]
      mapM_ (runOne tool) targets

runOne :: String -> String -> IO ()
runOne tool prop = do
  t0 <- getCurrentTime
  result <- try (driver tool prop) :: IO (Either SomeException Outcome)
  t1 <- getCurrentTime
  let us = round ((realToFrac (diffUTCTime t1 t0) :: Double) * 1e6) :: Int
  case result of
    Left e  -> emit tool prop "failed" 1 us Nothing (Just (show e))
    Right (Outcome status tests cex err) ->
      emit tool prop status tests us cex err

driver :: String -> String -> IO Outcome
driver "etna"       p = runWitnesses p
driver "quickcheck" p = runQuickCheck p
driver "hedgehog"   p = runHedgehog   p
driver "falsify"    p = runFalsify    p
driver "smallcheck" p = runSmallCheck p
driver tool         _ = pure (Outcome "aborted" 0 Nothing (Just ("unknown tool: " ++ tool)))

------------------------------------------------------------------------------
-- Tool: etna (witness replay)
------------------------------------------------------------------------------

runWitnesses :: String -> IO Outcome
runWitnesses prop = case witnessesFor prop of
  []    -> pure (Outcome "aborted" 0 Nothing (Just ("no witnesses for " ++ prop)))
  cs    -> go cs 0
  where
    go [] n = pure (Outcome "passed" n Nothing Nothing)
    go ((name, r):rest) n = do
      r' <- try (return $! r) :: IO (Either SomeException PropertyResult)
      case r' of
        Left e -> pure (Outcome "failed" (n + 1) (Just name) (Just (show e)))
        Right Pass    -> go rest (n + 1)
        Right Discard -> go rest (n + 1)
        Right (Fail msg) ->
          pure (Outcome "failed" (n + 1) (Just name) (Just msg))

witnessesFor :: String -> [(String, PropertyResult)]
witnessesFor "EscapedFieldHandlesLoneQuote" =
  [ ("witness_escaped_field_handles_lone_quote_case_lone_quote",
       W.witness_escaped_field_handles_lone_quote_case_lone_quote)
  , ("witness_escaped_field_handles_lone_quote_case_unbalanced",
       W.witness_escaped_field_handles_lone_quote_case_unbalanced)
  ]
witnessesFor "FoldrSkipsConversionErrors" =
  [ ("witness_foldr_skips_conversion_errors_case_left_right",
       W.witness_foldr_skips_conversion_errors_case_left_right)
  , ("witness_foldr_skips_conversion_errors_case_interleaved",
       W.witness_foldr_skips_conversion_errors_case_interleaved)
  ]
witnessesFor "FoldlSkipsConversionErrors" =
  [ ("witness_foldl_skips_conversion_errors_case_left_right",
       W.witness_foldl_skips_conversion_errors_case_left_right)
  , ("witness_foldl_skips_conversion_errors_case_interleaved",
       W.witness_foldl_skips_conversion_errors_case_interleaved)
  ]
witnessesFor "CustomDelimEscaped" =
  [ ("witness_custom_delim_escaped_case_semicolon",
       W.witness_custom_delim_escaped_case_semicolon)
  , ("witness_custom_delim_escaped_case_tab",
       W.witness_custom_delim_escaped_case_tab)
  ]
witnessesFor _ = []

------------------------------------------------------------------------------
-- Tool: quickcheck
------------------------------------------------------------------------------

runQuickCheck :: String -> IO Outcome
runQuickCheck "EscapedFieldHandlesLoneQuote" =
  qcDrive (QC.forAll GQ.gen_escaped_field_handles_lone_quote
             (qcProp P.property_escaped_field_handles_lone_quote))
runQuickCheck "FoldrSkipsConversionErrors" =
  qcDrive (QC.forAll GQ.gen_foldr_skips_conversion_errors
             (qcProp P.property_foldr_skips_conversion_errors))
runQuickCheck "FoldlSkipsConversionErrors" =
  qcDrive (QC.forAll GQ.gen_foldl_skips_conversion_errors
             (qcProp P.property_foldl_skips_conversion_errors))
runQuickCheck "CustomDelimEscaped" =
  qcDrive (QC.forAll GQ.gen_custom_delim_escaped
             (qcProp P.property_custom_delim_escaped))
runQuickCheck p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

qcProp :: (a -> PropertyResult) -> a -> QC.Property
qcProp f args = case f args of
  Pass     -> QC.property True
  Discard  -> QC.discard
  Fail msg -> QC.counterexample msg (QC.property False)

qcDrive :: QC.Property -> IO Outcome
qcDrive p = do
  result <- QC.quickCheckWithResult
              QC.stdArgs { QC.maxSuccess = 200, QC.chatty = False }
              p
  case result of
    QC.Success { QC.numTests = n } -> pure (Outcome "passed" n Nothing Nothing)
    QC.Failure { QC.numTests = n, QC.failingTestCase = tc } ->
      pure (Outcome "failed" n (Just (concat tc)) Nothing)
    QC.GaveUp  { QC.numTests = n } -> pure (Outcome "aborted" n Nothing (Just "QuickCheck gave up"))
    QC.NoExpectedFailure { QC.numTests = n } ->
      pure (Outcome "aborted" n Nothing (Just "no expected failure"))

------------------------------------------------------------------------------
-- Tool: hedgehog
------------------------------------------------------------------------------

runHedgehog :: String -> IO Outcome
runHedgehog "EscapedFieldHandlesLoneQuote" =
  hhDrive GH.gen_escaped_field_handles_lone_quote
          P.property_escaped_field_handles_lone_quote
runHedgehog "FoldrSkipsConversionErrors" =
  hhDrive GH.gen_foldr_skips_conversion_errors
          P.property_foldr_skips_conversion_errors
runHedgehog "FoldlSkipsConversionErrors" =
  hhDrive GH.gen_foldl_skips_conversion_errors
          P.property_foldl_skips_conversion_errors
runHedgehog "CustomDelimEscaped" =
  hhDrive GH.gen_custom_delim_escaped
          P.property_custom_delim_escaped
runHedgehog p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

hhDrive
  :: (Show a) => HH.Gen a -> (a -> PropertyResult) -> IO Outcome
hhDrive gen f = do
  let test = HH.property $ do
        args <- HH.forAll gen
        case f args of
          Pass     -> pure ()
          Discard  -> HH.discard
          Fail msg -> do
            HH.annotate msg
            HH.failure
  ok <- HH.check test
  if ok
    then pure (Outcome "passed" 200 Nothing Nothing)
    else pure (Outcome "failed" 1 Nothing Nothing)

------------------------------------------------------------------------------
-- Tool: falsify
------------------------------------------------------------------------------

runFalsify :: String -> IO Outcome
runFalsify "EscapedFieldHandlesLoneQuote" =
  fsDrive GF.gen_escaped_field_handles_lone_quote
          P.property_escaped_field_handles_lone_quote
runFalsify "FoldrSkipsConversionErrors" =
  fsDrive GF.gen_foldr_skips_conversion_errors
          P.property_foldr_skips_conversion_errors
runFalsify "FoldlSkipsConversionErrors" =
  fsDrive GF.gen_foldl_skips_conversion_errors
          P.property_foldl_skips_conversion_errors
runFalsify "CustomDelimEscaped" =
  fsDrive GF.gen_custom_delim_escaped
          P.property_custom_delim_escaped
runFalsify p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

fsDrive
  :: (Show a)
  => FG.Gen a
  -> (a -> PropertyResult)
  -> IO Outcome
fsDrive gen f = do
  let prop = do
        args <- FP.gen gen
        case f args of
          Pass     -> pure ()
          Discard  -> FP.discard
          Fail msg -> FP.testFailed (show args ++ ": " ++ msg)
  mFailure <- FI.falsify prop
  case mFailure of
    Nothing  -> pure (Outcome "passed" 100 Nothing Nothing)
    Just msg -> pure (Outcome "failed" 1 (Just msg) Nothing)

------------------------------------------------------------------------------
-- Tool: smallcheck
------------------------------------------------------------------------------

runSmallCheck :: String -> IO Outcome
runSmallCheck "EscapedFieldHandlesLoneQuote" =
  scDrive GS.series_escaped_field_handles_lone_quote
          P.property_escaped_field_handles_lone_quote
runSmallCheck "FoldrSkipsConversionErrors" =
  scDrive GS.series_foldr_skips_conversion_errors
          P.property_foldr_skips_conversion_errors
runSmallCheck "FoldlSkipsConversionErrors" =
  scDrive GS.series_foldl_skips_conversion_errors
          P.property_foldl_skips_conversion_errors
runSmallCheck "CustomDelimEscaped" =
  scDrive GS.series_custom_delim_escaped
          P.property_custom_delim_escaped
runSmallCheck p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

scDrive
  :: (Show a)
  => SCS.Series IO a
  -> (a -> PropertyResult)
  -> IO Outcome
scDrive series f = do
  countRef <- newIORef (0 :: Int)
  let depth = 5
      check args = SC.monadic $ do
        modifyIORef' countRef (+1)
        pure $ case f args of
          Pass    -> True
          Discard -> True
          Fail _  -> False
      smTest = SC.over series check
  res <- try (SCD.smallCheckM depth smTest)
           :: IO (Either SomeException (Maybe SCD.PropertyFailure))
  n <- readIORef countRef
  case res of
    Left e          -> pure (Outcome "failed" n Nothing (Just (show e)))
    Right Nothing   -> pure (Outcome "passed" n Nothing Nothing)
    Right (Just pf) -> pure (Outcome "failed" n (Just (show pf)) Nothing)

------------------------------------------------------------------------------
-- Output (single JSON line, exit 0 except on argv error)
------------------------------------------------------------------------------

emit :: String -> String -> String -> Int -> Int -> Maybe String -> Maybe String -> IO ()
emit tool prop status tests us cex err = do
  let q = quoteJSON
      esc Nothing  = "null"
      esc (Just s) = q s
  printf "{\"status\":%s,\"tests\":%d,\"discards\":0,\"time\":\"%dus\",\"counterexample\":%s,\"error\":%s,\"tool\":%s,\"property\":%s}\n"
    (q status) tests us (esc cex) (esc err) (q tool) (q prop)
  hFlush stdout

quoteJSON :: String -> String
quoteJSON s = '"' : concatMap esc s ++ "\""
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc '\r' = "\\r"
    esc '\t' = "\\t"
    esc c | fromEnum c < 0x20 = printf "\\u%04x" (fromEnum c)
          | otherwise = [c]
