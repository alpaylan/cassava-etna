# cassava — ETNA workload

This workload is a fork of [haskell-hvr/cassava](https://github.com/haskell-hvr/cassava) annotated with mined bug fixes from upstream history. The base tree is upstream `master` at commit `4deed6e1`; each variant under `patches/` is a `git format-patch`-shaped diff that, when **reverse**-applied, reintroduces a historical bug.

## Layout

```
.
├── src/                    upstream sources (untouched)
├── cabal.project           ours — `packages: . etna/`, pinned `with-compiler: ghc-9.6.6`
├── etna.toml               manifest (single source of truth)
├── patches/*.patch         bug-injection patches
├── etna/                   runner package (ours)
│   ├── etna-runner.cabal
│   ├── src/Etna/{Result,Properties,Witnesses}.hs
│   ├── src/Etna/Gens/{QuickCheck,Hedgehog,Falsify,SmallCheck}.hs
│   ├── app/Main.hs
│   └── test/Witnesses.hs
├── BUGS.md / TASKS.md      derived from etna.toml
└── progress.jsonl          per-run scratch log (gitignored)
```

## Build / run

```sh
cabal build exe:etna-runner            # builds the dispatcher
cabal test  etna-witnesses              # runs every witness; all green on base

cd etna
cabal run etna-runner -- quickcheck EscapedFieldHandlesLoneQuote
cabal run etna-runner -- hedgehog   FoldrSkipsConversionErrors
cabal run etna-runner -- falsify    FoldlSkipsConversionErrors
cabal run etna-runner -- smallcheck CustomDelimEscaped
cabal run etna-runner -- etna       All     # witness replay across all properties
```

Output is one JSON line per invocation (etna driver contract):

```
{"status":"passed|failed|aborted","tests":N,"discards":0,"time":"<us>us",
 "counterexample":STRING|null,"error":STRING|null,
 "tool":"etna|quickcheck|hedgehog|falsify|smallcheck","property":"<PropName>"}
```

## Variants

Four bug fixes are mined into properties (see `BUGS.md` for the full table):

| Property | Fix commit | Symptom |
|----------|-----------|---------|
| `EscapedFieldHandlesLoneQuote` | `14d401d3` | `decode "\""` raised `ByteString.init: empty` |
| `FoldrSkipsConversionErrors` | `6c9127e8` | `Foldable.foldr` over `Records` halted at first conversion error |
| `FoldlSkipsConversionErrors` | `e1de8377` | `Foldable.foldl'` over `Records` halted at first conversion error |
| `CustomDelimEscaped` | `8f1abb65` | `escape` only quoted on literal `,`, leaving custom-delimiter fields unescaped |

Each property is driven by **all four** PBT backends (QuickCheck, Hedgehog, Falsify, SmallCheck) plus the deterministic witness replay (`tool=etna`).

## Re-apply a variant manually

```sh
git apply -R --whitespace=nowarn patches/escaped_trailing_quote.patch  # install bug
cabal test etna-witnesses                                              # expect FAIL
git apply    --whitespace=nowarn patches/escaped_trailing_quote.patch  # restore base
```

## Toolchain

- `with-compiler: ghc-9.6.6` (set in `cabal.project`). Falsify ≥ 0.2 needs `base ≥ 4.18`, so GHC ≥ 9.6 is mandatory.
- Upstream cassava builds with the same compiler unmodified.
- Library deps for the runner: `cassava`, `bytestring`, `vector`, `deepseq`, `QuickCheck`, `hedgehog`, `falsify`, `smallcheck`.
