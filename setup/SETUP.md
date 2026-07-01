# makemera-contracts — Setup

Instructions to get this repo from empty to a working Foundry project. Nothing here has been run yet — this is the reference to follow when setup actually happens.

---

## 1. Install Foundry (system-level, one time)

Foundry provides the whole toolchain: `forge` (build/test/deploy), `cast` (chain interaction), `anvil` (local node), `chisel` (Solidity REPL).

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify:

```bash
forge --version
cast --version
anvil --version
```

Git is also required — Foundry manages dependencies as git submodules, not a package registry.

---

## 2. Initialize the project

From the `makemera-contracts/` root:

```bash
forge init
```

This scaffolds `src/`, `test/`, `script/`, `foundry.toml`, and adds `forge-std` automatically (cheatcodes, assertions, `console.log` — the only testing dependency needed).

Per `codebase.md`, contracts are versioned from day one — create the `V0/` subdirectory structure under `src/`, `test/`, and `script/` rather than putting contracts at the top of `src/` directly:

```
src/V0/
test/V0/
script/
```

---

## 3. Install project dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

This is the one real external dependency. It covers:
- `ERC721` — base implementation for `PassportNFT`
- `Ownable` / `AccessControl` — access control for `IdentifierRegistry`, `TheftRegistry` dispute resolution, etc., instead of hand-rolled auth

After install, confirm the remapping in `foundry.toml` or `remappings.txt` so `@openzeppelin/contracts/...` imports resolve:

```toml
remappings = ["@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"]
```

**Not a `forge install` dependency:** the ZK verifier contracts (`ZKVerifierIMEI.sol`, etc.) are generated output from `makemera-platform/packages/circuits` (circom + SnarkJS), committed directly into `src/V0/verifiers/`. They don't get pulled in here.

---

## 4. Recommended, not required to start

**Slither** (static analysis) — given this repo's stated lifecycle in `codebase.md` (audited, immutable once deployed, has its own `audits/` directory), this is worth adding before writing real contracts, not just as later polish:

```bash
pip install slither-analyzer
```

Formatting/linting needs no separate install — `forge fmt` is built into Foundry.

---

## 5. Sanity check

Once the above is done, these should all succeed on an empty scaffold:

```bash
forge build
forge test
```

---

*This file documents the setup steps only. See `../../solidity-concepts-reference.md` for Solidity language notes, and the top-level `codebase.md` / `About.md` (two directories up) for why this repo is structured the way it is.*
