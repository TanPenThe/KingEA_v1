# Required renderer scope extension — not applied

The active ResearchRunCoordinator.render_bundle is in research_pipeline/stage14.py and does not delegate to Stage12Pipeline.render_tester_bundle. The authorized production-file allowlist excludes stage14.py. It currently emits SET_AT_EXECUTION and takes calendar locations/hash copies from the child manifest.

The adjacent diff is the exact proposed stage14-only change. It depends on a new capture_render_inputs method in the already authorized successor_evidence.py, to be implemented and tested together after scope authorization. That method must independently resolve immutable-input references from externally pinned control context, capture each local file once, verify hashes, parse the captured manifest bytes against the authorized child, parse the captured calendar bytes, and return immutable captures. Manifest or SET copies must never select those references or the control root. Stage12 staging must write exactly those captures. The diff is a review proposal, not a currently apply-and-run patch.

No stage14 source changes have been made by this implementation. The existing dirty state is preserved. The existing successor enforcement continues to enforce its previous V2 contract and historical audit separation; V3 migration is outstanding and must not be represented as complete.

Authorize only this renderer change and its delegated independent-input helper, with the existing no-launch/no-root/B2 boundaries retained. The user's original plan expressly requires stopping an additional-file portion for review; this is that boundary.
