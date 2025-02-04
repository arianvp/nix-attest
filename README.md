# SLSA Provenance for nix

There are three levels of provenance that we're interested in.

## Eval-time provenance

What were the evaluation-time inputs to produce the resulting derivation.

Questions:

1. How does this work with IFD? 
2. How does this work with tvix where evaluation drives the build and there is no two separate phases