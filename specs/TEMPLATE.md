# Spec NNNN: <feature name>

- **Status**: draft | accepted | implemented | superseded by NNNN
- **Date**: YYYY-MM-DD
- **Author**: <who>

## Summary

One paragraph: what this feature is and why, in plain language.

## Problem

What is missing or wrong today, and who is affected. Concrete examples.

## Design

The chosen approach. Cover, as applicable:

- **SQL surface**: functions, table functions, settings, secrets, catalogs; their arguments and
  results.
- **DuckDB behaviour relied on**: what DuckDB does (with the source location on the duckdb
  submodule's commit) and how it was confirmed.
- **Licensing** (a licensed extension): what needs a licence, which limits the plans set, what
  happens in grace and after expiry, which usage is reported.
- **Dependencies**: new libraries (vcpkg) and their licences.

## Security

Why this is safe: what an untrusted input can reach, credentials and secrets, network access.

## Testing

How it is proven: the SQL tests in `test/sql`, and anything else.

## Alternatives considered

Options rejected and why (briefly).

## Follow-ups

Anything intentionally left out of scope.
