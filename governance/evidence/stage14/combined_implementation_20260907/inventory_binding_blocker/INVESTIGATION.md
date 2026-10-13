# V3 inventory binding: specification blocker

V3_INVENTORY_HASH_SCOPE = REQUIRES_OWNER_DECISION
IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW
SUCCESSOR_FREEZE = NOT_AUTHORIZED
B2 = LOCKED

## Exact controlling evidence

The adopted combined ADOPTION_RECORD.json incorporates PACKAGE_AND_TESTS.md at SHA256 15435AE5792F38A112C4C6451053274AF9E0E35962A8CC8C22600C176A8D7369. Its exact schema at line 17 requires integrity.archive_inventory_hash, says the archive inventory hashes sidecar bytes externally, and requires every referenced evidence hash to resolve in the exact inventory. A search of the incorporated A/S/combined review records found no alternate inventory generation, two-level inventory definition, or exact field exclusion that breaks the resulting dependency.

## Construction problem

Under the literal single-inventory interpretation:

- Sidecar S contains H(I) as archive_inventory_hash.
- Inventory I contains H(S), computed from the exact final sidecar bytes.

Neither final object can be serialized and hashed first. This is a cyclic hash dependency, not an ordinary missing checksum. Repeatedly replacing the hashes is not a governed construction protocol. The sentence excluding a self-hash does not identify whether a transitive inventory back-reference is excluded, which bytes are excluded, or whether two different inventories are intended. Choosing any of those interpretations changes the externally verifiable binding semantics.

The draft decision_a_evidence.validate_package does not yet validate this inventory reference or resolve all supporting evidence. It remains unintegrated and is not proof that the schema can be emitted/accepted correctly. Completing production V3 under that omission would violate the requested reference/inventory authority. No such bypass has been implemented.

## Recommended explicit resolution

Adopt PROPOSED_AMENDMENT.md: a prior reference inventory R hashes supporting evidence only; S binds H(R); a final archive inventory A hashes exact R, S and supporting evidence bytes. An independently retained archive seal pins H(A). No field is silently excluded from any file digest. The exact meaning of archive_inventory_hash becomes H(R), expressly not H(A).

This preserves accounting, containment, stop provenance, Stage13 v1 and all V3 top-level fields, but defines/changes an adopted integrity-field meaning and introduces explicit final-seal authority. It therefore meets the user's stop condition for a required adopted semantic decision. The alternative is an explicit canonical exclusion rule; it must be specified and adopted rather than guessed.

## Work and verification status

No production/test source was changed in this investigation. SOURCE_EQUALITY.json verifies all 246 prior checkpoint baselines, including protected Candidate/Stage13/governance sources. The accepted FINAL_PRE_TOOLING references and prior diffs/compile provenance remain intact. No new MQL compile is needed for unchanged sources; prior compilation remains compile-only. protocol_proof.py and its results are synthetic protocol-design evidence only, not accepted V3/runtime evidence.

The existing 244-test Python checkpoint remains the source implementation baseline; it does not close the new inventory specification issue. Full V3/native/containment production integration and its complete A/SP/SS/S test mapping remain incomplete. No acceptance is requested for the incomplete implementation.

No MT5/MetaTester, capacity work, Candidate/successor execution, research root, freeze or attempt occurred.
