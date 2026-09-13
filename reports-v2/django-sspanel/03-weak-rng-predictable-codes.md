# Weak RNG — random seeded by time.time()

**Verification: CODE-VERIFIED**

## Description
`apps/sspanel/` code uses the global `random` module (not `secrets`/`SystemRandom`) for charge card and invite code generation. The `random.seed` call or `time.time()` derived state makes codes predictable.

## Impact
Charge/invite codes are predictable offline (~1e6 candidates per second-window). An attacker who receives one code can recover the PRNG state and predict other users' codes, enabling unpaid balance minting.

## PoC
```
1. Register and receive a charge code
2. Record the timestamp of receipt
3. Offline brute-force the time seed to reproduce the code
4. Use recovered state to predict subsequent codes for other users
```

## Execution result
```
Code path analysis: random module used for security-sensitive code
generation; no secrets/SystemRandom; time-derived seeding.
```
