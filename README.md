# Vote Contract — Technical Reference

A StarkNet smart contract for running reusable, on-chain elections. Built in Cairo, deployed on Starknet Sepolia.

---

## Table of Contents

1. [What the contract does](#1-what-the-contract-does)
2. [Storage layout](#2-storage-layout)
3. [Election lifecycle](#3-election-lifecycle)
4. [The versioning pattern — why and how](#4-the-versioning-pattern--why-and-how)
5. [Why reset is O(1)](#5-why-reset-is-o1)
6. [Function reference](#6-function-reference)
7. [Events](#7-events)
8. [Access control](#8-access-control)
9. [Key invariants and guards](#9-key-invariants-and-guards)
10. [Architecture decisions and tradeoffs](#10-architecture-decisions-and-tradeoffs)
11. [Common gotchas](#11-common-gotchas)

---

## 1. What the contract does

The Vote contract allows an admin to run a multi-candidate election on-chain. Each election goes through three states: `NotStarted → Ongoing → Ended`. After an election ends, the admin can reset the contract to run a brand new election — without redeploying and without erasing any historical data.

At a high level:

- Admin adds up to 5 candidates before the election starts
- Admin starts the election
- Any wallet can cast exactly one vote for a candidate
- Admin ends the election
- Anyone can query the winner and vote breakdown
- Admin resets the contract to start the next election round

Every action is gated by state checks so the flow cannot be skipped or abused.

---

## 2. Storage layout

```cairo
#[storage]
struct Storage {
    admin:            ContractAddress,
    election_id:      u64,
    election_state:   ElectionState,

    voters:           Map<(u64, ContractAddress), bool>,
    candidates:       Map<(u64, u64), Candidate>,
    candidate_ids:    Map<(u64, u64), u64>,
    candidates_count: Map<u64, u64>,
}
```

### What each field does

`admin` — the deployer address. Only this address can call state-mutating admin functions.

`election_id` — a monotonically incrementing counter. Starts at `0`. Every time the admin resets the contract it increments by 1. This single value is the entire reset mechanism — see section 4.

`election_state` — an enum with three variants:

```cairo
enum ElectionState {
    NotStarted,  // 0 — default, candidates can be added
    Ongoing,     // 1 — voting is live
    Ended,       // 2 — voting closed, winner queryable
}
```

`voters` — keyed by `(election_id, voter_address)`. Stores whether a wallet has voted in the **current** election round. Old rounds' entries are still in storage but unreachable under the new key.

`candidates` — keyed by `(election_id, candidate_id)`. Stores the `Candidate` struct (id + vote_count) for each candidate in the current round.

`candidate_ids` — keyed by `(election_id, index)`. Maps a positional index to a candidate_id. This is the manual counter pattern that replaces `Vec<u64>` — read more in section 4.

`candidates_count` — keyed by `election_id`. Stores how many candidates have been added in the current round. This is the length tracker for the manual counter pattern.

---

## 3. Election lifecycle

```
Deploy
  │
  ▼
NotStarted (election_id = N)
  │  admin calls add_candidate() up to 5 times
  │
  ▼
start_election()   ← requires at least 2 candidates
  │
  ▼
Ongoing
  │  any wallet calls vote(candidate_id)
  │  each wallet can only vote once per round
  │
  ▼
end_election()
  │
  ▼
Ended
  │  get_winner() and calculate_votes() now available
  │
  ▼
reset_vote_state()   ← increments election_id, state → NotStarted
  │
  ▼
NotStarted (election_id = N+1)   ← cycle repeats
```

The state machine is strictly linear. You cannot go backwards. You cannot skip a step. Every transition has an `assert` that panics with a clear message if the precondition is not met.

---

## 4. The versioning pattern — why and how

### The problem this solves

After an election ends, a naive reset would need to:

1. Zero out every candidate's vote count
2. Clear every voter's record
3. Clear the candidate list
4. Set the state back to `NotStarted`

Steps 1–3 require iterating over every item that was written — which costs gas proportional to the number of candidates and voters. For a contract with many voters this becomes expensive and unbounded.

More critically, StarkNet's `Map<K, V>` **has no built-in way to iterate or enumerate its keys**. A `Map` is a pure hash-derived slot lookup — it computes a storage address from `hash(base_path + key)` and reads or writes that slot. The contract itself has no record of which keys were ever touched. This is the same fundamental limitation as Solidity's `mapping`.

This means to clear a `Map<ContractAddress, bool>` (voters), you would need to maintain a separate list of every voter address so you can loop through and reset each one. That is extra gas on every vote just to support a future reset.

### The solution: scope all data under election_id

Instead of deleting anything, every storage key that is round-specific includes the current `election_id` as part of the key:

```cairo
// voters in round 0
voters: Map<(u64, ContractAddress), bool>
// key for voter 0xABC in round 0 → hash("voters", 0, 0xABC)
// key for voter 0xABC in round 1 → hash("voters", 1, 0xABC)
```

These are entirely different storage slots. When the election_id changes, the old data does not need to be touched — it just becomes unreachable under the new keys.

Reset is then a two-write operation:

```cairo
fn reset_vote_state(ref self: ContractState) {
    only_admin(@self);
    assert(self.election_state.read() == ElectionState::Ended, 'not ended');

    let new_id = self.election_id.read() + 1;
    self.election_id.write(new_id);                        // write 1
    self.election_state.write(ElectionState::NotStarted);  // write 2

    self.emit(Election_Reset { new_election_id: new_id });
}
```

That is the entire reset function. Two storage writes regardless of how many candidates were added or how many voters participated.

### The bonus: full election history is preserved

Because old data is scoped under old election_ids, every round's votes and candidates are permanently stored on-chain. You can read historical data by passing old election_ids directly to the storage maps off-chain. This is a feature, not just a side effect — full auditability with zero extra work.

---

## 5. Why reset is O(1)

### O(1) means constant time — does not grow with input size

The versioning pattern means the cost of `reset_vote_state` is always the same: two storage writes. It does not matter if round 0 had 3 voters or 300,000 voters. The reset does not touch voter data at all.

### What the alternative would look like

If we had used the naive delete-everything approach:

```
voters: Map<ContractAddress, bool>
```

We would need to track every voter address in a parallel `Vec<ContractAddress>` (because Maps can't be iterated), then on reset:

```cairo
// O(n) — iterates every voter
let voters_len = self.voters_list.len();
let mut j = 0;
while j < voters_len {
    let addr = self.voters_list.at(j).read();
    self.voters.entry(addr).write(false);
    j += 1;
};
```

This is O(n) where n is the number of voters. In a popular election with thousands of participants, this loop would cost a significant amount of gas and could eventually hit block gas limits, making the contract permanently stuck in the `Ended` state with no way to reset.

### Comparison table

| Operation | Versioning pattern | Delete-everything pattern |
|---|---|---|
| `reset_vote_state` gas | Fixed — 2 writes | Grows with voter count |
| `vote` gas | Same as before | +1 extra write per vote (tracking voter address for future reset) |
| Historical data | Preserved on-chain | Erased |
| Risk of stuck contract | None | Yes — if voters > gas limit |
| Code complexity | Simple | Requires parallel Vec + cleanup loop |

---

## 6. Function reference

### Admin functions

**`add_candidate(candidate_id: u64)`**

Adds a candidate to the current election round. Internally writes to `candidates` and `candidate_ids` under the current `election_id`, and increments `candidates_count`.

Guards:
- Caller must be admin
- Election state must be `NotStarted` (cannot add after election starts)
- `candidates_count` for current round must be less than 5
- Candidate must not already exist in this round (checked by reading its slot — if `id == 0` it was never written)

**`start_election()`**

Transitions state from `NotStarted` to `Ongoing`.

Guards:
- Caller must be admin
- Must have at least 2 candidates in current round
- State must be `NotStarted`

**`end_election()`**

Transitions state from `Ongoing` to `Ended`.

Guards:
- Caller must be admin
- State must be `Ongoing`

**`reset_vote_state()`**

Increments `election_id` and sets state back to `NotStarted`. Does not touch any voter or candidate data.

Guards:
- Caller must be admin
- State must be `Ended`

### User function

**`vote(candidate_id: u64)`**

Records a vote for the given candidate in the current election round.

Guards:
- State must be `Ongoing`
- Caller must not have voted in this round (checks `voters[(election_id, caller)]`)
- Candidate must exist in this round (checks `candidates[(election_id, candidate_id)].id != 0`)

On success: increments `candidates[(election_id, candidate_id)].vote_count` and sets `voters[(election_id, caller)] = true`.

### View functions

**`get_election_state() → u8`**

Returns `0` (NotStarted), `1` (Ongoing), or `2` (Ended).

**`get_election_id() → u64`**

Returns the current election round number. Starts at `0`, increments by `1` on each reset. Useful on the frontend to know which round is active and to confirm a reset succeeded.

**`get_candidates_length() → u64`**

Returns how many candidates have been added in the current round. Reads `candidates_count[election_id]`.

**`get_candidate(candidate_id: u64) → (u64, u64)`**

Returns `(candidate_id, vote_count)` for a specific candidate in the current round. Panics with `'candidate not found'` if the candidate does not exist.

**`calculate_votes() → Array<(u64, u64)>`**

Returns an array of `(candidate_id, vote_count)` tuples for all candidates in the current round, in insertion order. Works at any election state.

**`get_winner() → u64`**

Returns the `candidate_id` of the winner. Panics if state is not `Ended` or if no votes were cast. Does not handle ties — returns the first candidate encountered with the highest vote count.

**`has_voted(voter_address: ContractAddress) → bool`**

Returns whether the given address has voted in the current round. Panics if state is not `Ongoing` — this guard exists because the function only makes semantic sense while an election is live.

---

## 7. Events

Every state change emits an event. Events are the on-chain audit log.

| Event | When emitted | Fields |
|---|---|---|
| `Candidate_Added` | A candidate is successfully added | `candidate_id: u64` |
| `Election_Started` | Election transitions to Ongoing | none |
| `Election_Ended` | Election transitions to Ended | none |
| `Election_Reset` | Contract resets to new round | `new_election_id: u64` |
| `Voted` | A vote is successfully cast | `voter: ContractAddress`, `candidate_id: u64` |

The `Election_Reset` event carries `new_election_id` so the frontend can immediately update its state after the transaction confirms, without needing to call `get_election_id` again.

---

## 8. Access control

All state-mutating admin functions route through a single private helper:

```cairo
fn only_admin(self: @ContractState) {
    let caller = get_caller_address();
    assert(caller == self.admin.read(), 'only admin');
}
```

The admin is set once in the constructor and never changes. There is no admin transfer function. The admin address is passed as a constructor argument at deployment time.

---

## 9. Key invariants and guards

These are the rules the contract enforces at all times. Understanding these helps you know what will panic and why.

**Candidate exists check:** Instead of maintaining a separate "does this candidate exist" boolean, the contract checks `candidate.id == 0`. Since a zero id is the default unwritten state in Cairo storage (storage slots initialize to zero), a candidate with `id == 0` was never written. This works because valid candidate ids are user-supplied and must be non-zero in practice.

**State linearity:** The state machine only moves forward. `NotStarted → Ongoing → Ended`. Reset creates a new round at `NotStarted` — it does not go backwards on the same round.

**Voter scope:** A voter's record is scoped to `(election_id, address)`. After a reset, the same address starts with a clean slate in the new round. This is the direct consequence of the versioning pattern.

**Candidate scope:** Candidates are scoped to `(election_id, candidate_id)`. The same candidate id can be reused across rounds without conflict because the keys are different.

**`has_voted` only works during Ongoing:** The function asserts the election is `Ongoing`. This is intentional — after the election ends the voter Map entries still exist (they're never deleted), but querying them post-election is semantically meaningless and could mislead callers, so the guard prevents it.

---

## 10. Architecture decisions and tradeoffs

### Why `Map<(u64, u64), u64>` instead of `Vec<u64>` for candidate_ids

`Vec<u64>` has no `clear()` method in StarkNet's storage API. The internal length counter has no public write handle, so there is no way to reset a Vec's length to zero through the standard API. You would be stuck iterating and zeroing elements, and even then the length would still report stale data.

The manual counter pattern solves this cleanly:

```cairo
candidate_ids:    Map<(u64, u64), u64>,   // (election_id, index) → candidate_id
candidates_count: Map<u64, u64>,           // election_id → count
```

Push = write at index `count`, increment `count`. Iterate = loop `0..count`. Reset = write `count = 0` (or in our case, move to a new election_id where the count slot has never been touched, so it reads as `0` automatically).

### Why MAX_CANDIDATES is 5

Bounding the candidate list bounds iteration cost in `calculate_votes` and `get_winner`. These functions loop through all candidates. With an unbounded list, a malicious admin could add thousands of candidates and make these view functions prohibitively expensive. Five is the chosen limit for this contract — adjust the constant if your use case needs more.

### Why candidate ids are user-supplied u64s instead of auto-assigned

Candidate ids map to off-chain identity (a person, a database record, an IPFS hash index). The frontend maps these ids to names and images in its own data layer. The contract does not store strings or metadata — keeping it lean and gas-efficient.

### Why there is no admin transfer

Simplicity. For a voting contract, the admin is the election authority. Changing the authority mid-election introduces governance complexity that this contract intentionally avoids. If admin transfer is needed, it can be added as a separate function with appropriate state guards.

---

## 11. Common gotchas

**Adding a candidate with id 0 will behave incorrectly.** The contract uses `candidate.id == 0` as the sentinel for "not written". A candidate added with id `0` would appear to not exist on the first read. Enforce `candidate_id > 0` validation on the frontend or add an explicit assert in `add_candidate`.

**`has_voted` panics outside Ongoing state.** If your frontend calls `has_voted` when the election is `NotStarted` or `Ended`, the transaction will revert. Guard the call with a state check: only call `has_voted` when `get_election_state() == 1`.

**`get_winner` returns the first highest-vote candidate on a tie.** The loop does `>` not `>=` when comparing vote counts, so the first-inserted candidate wins ties. There is no explicit tie detection in `get_winner` — use `calculate_votes` on the frontend to detect and display ties.

**`calculate_votes` works at any state.** Unlike `get_winner`, `calculate_votes` has no state guard. You can call it during `NotStarted` (returns all zeros), `Ongoing` (live counts), or `Ended` (final counts). This is intentional for live result display on the frontend.

**After reset, `election_id` increments but old data is still on-chain.** Old rounds' data is not deleted — it remains in storage slots keyed under old election_ids. This is by design for auditability. It does not affect gas costs for new rounds since new storage slots are used.

**The `voters` Map cannot be queried for all voters.** There is no way to enumerate who voted — only whether a specific address voted. This is a fundamental property of StarkNet's `Map` type. If you need an enumerable voter list, you would need to add a parallel `Map<(u64, u64), ContractAddress>` + voter count, following the same manual counter pattern used for candidates.