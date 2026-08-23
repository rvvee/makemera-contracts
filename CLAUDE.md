# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## What this is

Solidity smart contracts for makemera — a blockchain-based trust platform for
used electronics resale. Issues cryptographic device "passports" (ERC-721 NFTs
with ZK proofs) that travel with devices across sales. Deployed to Base.

This repo has a different lifecycle from `makemera-platform`: contracts are
audited and immutable once deployed. Treat changes here as higher-stakes than
typical app code.

## Commands

- Build: `forge build`
- Test: `forge test`
- Test with gas report: `forge test --gas-report`
- Coverage: `forge coverage`
- Single test: `forge test --match-test test_FunctionName_Scenario`

## Test conventions

- Naming: `test_<Function>_<Scenario>`
- Every state-changing function needs tests for: access control, input
  validation, precondition reverts, happy path, event emission, and
  side-effect isolation.
- **Draft test case names only (no code) for review before writing any test.**
  This is a strict workflow rule — don't skip straight to implementation.

## Git workflow

- Branch naming: `feat/<contract-or-feature>`, `fix/<short-desc>`,
  `test/<contract-name>`
- Commit format: Conventional Commits (`feat:`, `fix:`, `test:`, `refactor:`)
- `forge test` must pass before any commit
- Never push directly to `main` — feature branch + PR, even solo
- Never force-push

## Do NOT

- Do not write implementation code before architectural decisions are
  explicitly confirmed — decisions come first, always.
- Do not add OpenZeppelin imports to `NullifierRegistry`.
- Do not pass verifier addresses as parameters to `VerifierRouter` functions.
- Do not deploy to Base mainnet from this repo without explicit confirmation.
- Do not touch `.zkey` files — those live in `makemera-platform/packages/circuits`
  and are never committed anywhere.

## Related docs

These live one level up, outside this repo (not tracked/pushed here):

- `../About.md` — full product context and legal constraints
- `../codebase.md` — repo topology and dependency flow (authoritative for structure)
- `../Chain-Selection.md` — why Base, don't relitigate without reading this first
- `../solidity-concepts-reference.md` — Solidity concept notes