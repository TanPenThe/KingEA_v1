# Proposed V3 acyclic inventory binding amendment

PROPOSED_ONLY — NOT_ADOPTED

Scope: serialization/hash-reference authority only. No economics, safety behavior, execution authority or Stage13 schema change.

1. Construct a REFERENCE_INVENTORY_V1 record R after all supporting lifecycle facts, request/receipt records, stop/profile references, snapshots, swap reconciliations and Stage13 commit evidence have been sealed. Each entry records exact run/group identity, role, unique relative artifact path, byte length and uppercase SHA256 of complete artifact bytes. R excludes itself, the terminal V3 sidecar S and the final archive inventory A.
2. Define the existing V3 sidecar integrity.archive_inventory_hash as SHA256 of the complete bytes of R. All supporting evidence hashes referenced by S must resolve to an entry of R, except this R hash itself. Exact scope/role identity must match; existence of an arbitrary same-hash file is not authority.
3. Serialize S once. Its complete byte digest includes integrity.archive_inventory_hash. Do not remove/zero any field for hashing. Keep the currently adopted V3 field set unchanged.
4. Construct FINAL_ARCHIVE_INVENTORY_V1 record A listing complete-byte hashes and lengths for R, S, and exactly the supporting artifacts enumerated in R. A excludes itself. The S record identifies its exact V3 role and run/group. No duplicate path, duplicate role assignment, traversal, alias, undeclared artifact or missing artifact is permitted.
5. An independently retained final archive seal pins SHA256(A), the exact run/group and expected V3 semantic/adoption/execution/profile identities. The final archive seal is supplied by independent control context, never selected by S, a frame, a result or an arbitrary archive path. It verifies completed evidence integrity only and grants no execution, root, freeze, budget, selection or Gate 2 authority.
6. Verification order is independent archive seal -> exact A bytes -> exact R/S/supporting bytes -> R coverage/scope/role -> S references and lifecycle/accounting/Stage13 rules. Every arrow is one-way. Missing, altered, foreign, wrong-role, undeclared or downgraded evidence rejects before any accepted result/package or financial acceptance transition. Retain the existing canonical successor rejection with stage/detail.
7. No code may accept the old ambiguous/cyclic convention prospectively or infer this new convention from a payload. An explicit adopted integrity convention must be bound in the independently reviewed successor control specification. Historical audit-only semantics and sealed Candidate 001 evidence remain unchanged.

This amendment is a proposed protocol definition, not owner adoption, an archive seal, successor freeze or execution receipt. Production implementation of this convention awaits the owner's explicit decision.
