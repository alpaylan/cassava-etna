module Main where

import           Control.Exception (SomeException, try)
import           Etna.Result       (PropertyResult(..))
import           Etna.Witnesses
import           System.Exit       (exitFailure, exitSuccess)

cases :: [(String, PropertyResult)]
cases =
  [ ("witness_escaped_field_handles_lone_quote_case_lone_quote",
       witness_escaped_field_handles_lone_quote_case_lone_quote)
  , ("witness_escaped_field_handles_lone_quote_case_unbalanced",
       witness_escaped_field_handles_lone_quote_case_unbalanced)
  , ("witness_foldr_skips_conversion_errors_case_left_right",
       witness_foldr_skips_conversion_errors_case_left_right)
  , ("witness_foldr_skips_conversion_errors_case_interleaved",
       witness_foldr_skips_conversion_errors_case_interleaved)
  , ("witness_foldl_skips_conversion_errors_case_left_right",
       witness_foldl_skips_conversion_errors_case_left_right)
  , ("witness_foldl_skips_conversion_errors_case_interleaved",
       witness_foldl_skips_conversion_errors_case_interleaved)
  , ("witness_custom_delim_escaped_case_semicolon",
       witness_custom_delim_escaped_case_semicolon)
  , ("witness_custom_delim_escaped_case_tab",
       witness_custom_delim_escaped_case_tab)
  ]

evalCase :: (String, PropertyResult) -> IO (String, PropertyResult)
evalCase (n, r) = do
  e <- try (return $! r) :: IO (Either SomeException PropertyResult)
  pure (n, either (\ex -> Fail (show ex)) id e)

main :: IO ()
main = do
  evald <- mapM evalCase cases
  let failures =
        [ (n, msg) | (n, Fail msg) <- evald ] ++
        [ (n, "discard") | (n, Discard) <- evald ]
  if null failures
    then do
      putStrLn $ "OK: all " ++ show (length cases) ++ " witnesses passed"
      exitSuccess
    else do
      mapM_ (\(n, m) -> putStrLn (n ++ ": FAIL: " ++ m)) failures
      exitFailure
