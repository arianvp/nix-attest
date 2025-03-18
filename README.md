# SLSA Provenance for nix

There are few levels of provenance that we're interested in.

## Eval-time provenance

What were the evaluation-time inputs to produce the resulting derivation?

Questions:

1. How does this work with IFD? 
2. How does this work with dynamic-derivations?
2. How does this work with tvix where evaluation drives the build and there is no two separate phases?


## Build-time provenance

* What was the derivation that built a set of out-paths
* what were build-time dependencies of that derivation
* What builder built the derivation

## run-time provenance


We can kind of divide into two groups:

* Things that you always want to check
* Things that you want to check in a post-compromise scenario

E.g. when substituting an out-path; you want to know the references of the out-path 



## (exploding brain meme) Builder-time provenance

* What derivation built the builder that built the derivation?

## (CA-derivatiins) Realisation-time provenance