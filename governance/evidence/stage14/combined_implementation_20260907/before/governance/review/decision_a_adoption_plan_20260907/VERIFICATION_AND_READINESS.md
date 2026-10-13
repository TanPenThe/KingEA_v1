# Deterministic verification, native conformance and readiness

## Deterministic test mapping

The retained A01-A25, SP01-SP16 and SS01-SS19 identifiers are design references, not claimed executions. The owner-adopted controlled-context rule supersedes earlier SP expectations requiring complete actor logs for otherwise independently verified isolated tester context.

| Proposed test file | Existing case mapping | Required assertions |
|---|---|---|
| tests/test_decision_a_evidence.py (new) | A01-A21; SP02-SP07/SP12-SP14; SS03-SS07/SS14/SS17-SS18 | Signed oracle, zero/read failures, linkage, full volume, external cash isolation, origin/stop state, wrong authority/profile and no acceptance/inventory write |
| MQL5/Scripts/KingEA/TestDecisionA.mq5 (new) | A01/A04/A06-A10/A13-A19/A22-A25 | Exercise actual pure MQL ledger and projection seam; no trades; duplicates/conflicts/one-time booking, boundary precedence, safety continuity |
| tests/test_decision_a_policy.py (new) | SS02/SS04 plus reduction denial | Static call closure, no alternate send/SLTP/import/shared-input command route, prohibited reductions rejected before send |
| Same pure MQL harness | SP08-SP11/SP15-SP16; SS08-SS13/SS16 | Sticky mutation invalidity, bounded ring overflow, ordering ambiguity, wrong ticket/stable-ID mapping, no fake native completeness |
| tests/test_successor_evidence.py (existing, extend) | Existing E01-E18 plus Decision A profile negatives | Canonical successor rejection retained, authority co-tampering denied, historical evidence cannot satisfy prospective Decision A |

Positive controlled-context test: independent profile and source closure + entry S0 + native SL cause + exit S0, no observed violation, full valid accounting lifecycle. Negative context-loss test: same endpoint values with missing/mismatched isolation proof rejects. Demo/live cannot use tester receipt. Successful synthetic controls prove conformance only.

Run full Python suite and applicable MQL non-order regression suite after implementation. Running a MQL script in MT5, even one with no orders, still requires separate launch authorization; compilation and Python tests alone cannot be reported as execution of MQL behavior. Python mirrors do not substitute for MQL seam coverage.

## Deferred native conformance plan

Create a separately reviewed infrastructure harness (proposed new MQL5/Experts/KingEA/DecisionAConformance.mq5), never a successor research root or attempt. Before any separately authorized storage-intensive test: report required free space, actual free space and shortfall using governed sizing, then recheck immediately before manual launch. No capacity sample or launch now.

Bind harness and actual prospective production dependencies/build/profile hashes, with explicit distinction between harness tests and production integration proof. Cases: long/short full close; long/short SL including gap; successful effective entry S0; nonzero signed costs where supported; successful zero; callback ordering; normal/boundary conflict; full-close safety valuation continuity; profile/source tampering; observation failure and internal overflow. Failure injections occur only in the harness. Do not inject partial-position activity as valid Decision A evidence.

Tester isolation checks must verify local/nonvisual operation, MQL_TESTER, disabled DLLs, frozen executable/dependencies/input closure, output-only FILE_COMMON behavior and absence of command bridges. No live-account trade is necessary or authorized to test isolation. A boundary conflict after sealing remains invalid with both records preserved. Upstream queue completeness is never inferred from an empty internal ring or contiguous local counters.

Retain callback facts/read flags, position mapping, requested/confirmed S0, component records, profile receipt, one-time Stage13 event, hashes, failures, and producer/consumer reconciliation. Require exact accepted component totals, no second projection and no acceptance on profile/provenance failure. Broker costs that cannot be attributed under narrow authority fail rather than being estimated. Manual launch and independent acceptance are separate steps.

## Readiness blockers

| Blocker | Status / required closure |
|---|---|
| Specification adoption | Complete for controlled Strategy Tester only; exact record in ADOPTION_RECORD.json |
| Actual implementation | Not yet accepted; current directive authorizes this plan only |
| Fresh PRE_TOOLING | Must be captured immediately before separately authorized source changes, binding adopted spec hash; planning baseline is not a substitute |
| Actual tester profile | Independently verified frozen EA/dependency/compiler/terminal/agent/SET/INI/specification evidence outstanding |
| FILE_COMMON compliance | Existing shared-file readers must be audited against output-only rule; no grandfathered shared input. Any needed input migration must be explicitly designed within the proposed tester integration before implementation |
| Prospective evidence semantics | New exact discriminator and consumer propagation need review; no silent reuse of historical whole-position V2 declarations |
| Safety reduction trigger | Operational response unresolved while caller unavailable; no suppression, flattening substitution or Decision S implementation by inference |
| Implementation/regressions | Deterministic and actual MQL seam proof outstanding |
| Native integration/conformance | Not performed; separate authorization, prerequisites, launch and independent acceptance required |
| Housekeeping | Existing fail-closed semantics unchanged; no new authority |
| Demo/live stop provenance | Unresolved; excluded from adoption |
| Successor/B2 | Freeze not authorized; own Gate 1 and exact-root/budget authorization absent; B2 locked |

Candidate001 source and both Decision S documents remain unchanged; hashes are in PRESERVATION.json. No research execution or automatic advancement follows specification adoption.
