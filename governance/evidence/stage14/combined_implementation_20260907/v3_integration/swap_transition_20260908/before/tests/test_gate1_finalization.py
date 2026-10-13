import hashlib
import json
import tarfile
import tempfile
import unittest
from shutil import rmtree
from pathlib import Path

from research_pipeline.gate1_finalization import (
    Gate1FinalizationRequest,
    Gate1Finalizer,
)
from research_pipeline.historical_audit import (
    HistoricalAuditIntegrityError,
    HistoricalAuditScope,
    RetiredHistoricalGate1Audit,
)


def canonical_hash(value):
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest().upper()


class FinalizationFixture:
    def __init__(self, root: Path):
        self.root = root
        self.prior = root / "prior"
        self.continuation = root / "continuation"
        self.parity = root / "parity"
        self.execution = root / "execution"
        self.archives = root / "archives"
        self.output = root / "output"
        for path in (
            self.prior,
            self.continuation,
            self.parity,
            self.execution,
            self.archives,
        ):
            path.mkdir(parents=True)

        self.prior_root = self._write_epoch(
            self.prior, "A" * 64, "G1-0000", "RECORDED", 0
        )
        self.continuation_root = self._write_epoch(
            self.continuation, "B" * 64, "G1-0001", "RSB3", 1
        )
        inventory = {
            "kind": "GATE1_ACCEPTED_COMPLETED_EVIDENCE_INVENTORY",
            "completed_count": 1,
            "first_run_id": "G1-0000",
            "last_run_id": "G1-0000",
            "prior_root_sha256": self.prior_root,
            "rows": [{"run_id": "G1-0000", "manifest_sha256": "1" * 64}],
        }
        inventory["inventory_sha256"] = canonical_hash(inventory)
        (self.continuation / "COMPLETED_EVIDENCE_INVENTORY.json").write_text(
            json.dumps(inventory), encoding="utf-8"
        )
        parity = {
            "status": "PASS",
            "prior_root_sha256": self.prior_root,
            "continuation_root_sha256": self.continuation_root,
            "comparison_count": 1,
        }
        parity["result_sha256"] = canonical_hash(parity)
        (self.parity / "PARITY_RESULT.json").write_text(
            json.dumps(parity), encoding="utf-8"
        )
        (self.continuation / "GATE1_AUTHORIZATION.json").write_text(
            json.dumps(
                {
                    "owner_approved": True,
                    "root_sha256": self.continuation_root,
                    "oos_authorized": False,
                    "holdout_authorized": False,
                }
            ),
            encoding="utf-8",
        )

    def _write_epoch(
        self, package: Path, root_sha: str, run_id: str, branch: str, configuration: int
    ) -> str:
        manifest_sha = "1" * 64 if run_id == "G1-0000" else "2" * 64
        child = {
            "run_id": run_id,
            "manifest_sha256": manifest_sha,
            "partition": "FOLD_1_TRAIN",
            "branch": branch,
            "configuration_start": configuration,
            "configuration_end": configuration,
        }
        child_path = package / "children" / f"{run_id}.json"
        child_path.parent.mkdir(parents=True)
        child_path.write_text(json.dumps(child), encoding="utf-8")
        index = {
            "kind": "GATE1_CHILD_INDEX",
            "root_sha256": root_sha,
            "child_count": 1,
            "children": [
                {
                    "run_id": run_id,
                    "path": str(child_path),
                    "manifest_sha256": manifest_sha,
                    "file_sha256": hashlib.sha256(child_path.read_bytes())
                    .hexdigest()
                    .upper(),
                }
            ],
        }
        index["index_sha256"] = canonical_hash(index)
        (package / "CHILD_INDEX.json").write_text(json.dumps(index), encoding="utf-8")
        gate_root = {
            "kind": "GATE1_TEST_FIXTURE",
            "candidate_id": "TEST-CANDIDATE",
            "root_sha256": root_sha,
            "configuration_pass_count": 1,
        }
        (package / "GATE1_ROOT.json").write_text(json.dumps(gate_root), encoding="utf-8")
        self._write_zero_archive(run_id, manifest_sha, child)
        return root_sha

    def _write_zero_archive(self, run_id: str, manifest_sha: str, child: dict):
        spool = self.root / f"spool-{run_id}"
        spool.mkdir()
        configuration = child["configuration_start"]
        stage12 = (
            f"config={configuration}|branch={child['branch']}|"
            f"partition={child['partition']}|entries=0|exits=0|missed=0|"
            "delay_expiry=0|gate_reject_after_delay=0|"
            "virtual_execution_failure=0|hard_failures=0|complete=1|"
            "trade_returns=|trade_r=|daily_returns=0.000000000000"
        )
        stage13 = (
            "schema=1|event_count=0|close_count=0|trade_return_count=0|"
            "legacy_net=0.000000000000|ledger_net=0.000000000000|"
            "root=|complete=1"
        )
        (spool / f"{configuration}_KINGEA_STAGE12_COMPLETE_{configuration}.frame").write_text(
            stage12, encoding="utf-8"
        )
        (spool / f"{configuration}_KINGEA_STAGE13_ACCOUNTING_COMPLETE_{configuration}.frame").write_text(
            stage13, encoding="utf-8"
        )
        archive = self.archives / f"{run_id}_{manifest_sha}.tar.gz"
        with tarfile.open(archive, "w:gz") as handle:
            for path in sorted(spool.iterdir()):
                handle.add(path, arcname=f"./{path.name}")
        rows = sorted((path.name, path.stat().st_size) for path in spool.iterdir())
        metadata = hashlib.sha256()
        samples = {}
        for name, size in rows:
            metadata.update(name.encode() + b"\0" + str(size).encode() + b"\n")
            samples[name] = hashlib.sha256((spool / name).read_bytes()).hexdigest().upper()
        marker = {
            "schema": 1,
            "status": "ARCHIVED_VERIFIED",
            "run_id": run_id,
            "manifest_sha256": manifest_sha,
            "file_count": len(rows),
            "logical_bytes": sum(size for _, size in rows),
            "metadata_sha256": metadata.hexdigest().upper(),
            "sample_count": len(samples),
            "sample_set_sha256": hashlib.sha256(
                json.dumps(samples, sort_keys=True).encode()
            )
            .hexdigest()
            .upper(),
            "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest().upper(),
            "archive_path": str(archive),
            "loose_files_removed": True,
        }
        (self.archives / f"{run_id}_{manifest_sha}.ARCHIVED.json").write_text(
            json.dumps(marker), encoding="utf-8"
        )
        complete = self.execution / "children" / run_id / "COMPLETE.json"
        complete.parent.mkdir(parents=True)
        complete.write_text(
            json.dumps(
                {
                    "status": "COMPLETE",
                    "run_id": run_id,
                    "manifest_sha256": manifest_sha,
                }
            ),
            encoding="utf-8",
        )

    def request(self):
        return Gate1FinalizationRequest(
            prior_package=self.prior,
            continuation_package=self.continuation,
            parity_package=self.parity,
            archive_root=self.archives,
            execution_root=self.execution,
            output_root=self.output,
            allow_test_fixture=True,
        )

    def historical_audit(self):
        request = self.request()
        scope = HistoricalAuditScope(
            scope_id="RETIRED_GATE1_TEST_FIXTURE",
            schema_version=1,
            record_identity=Gate1Finalizer.historical_record_identity(request),
        )
        return RetiredHistoricalGate1Audit(scope)

    def rewrite_with_trade(self, run_id: str, *, stage13_return: str):
        manifest_sha = "1" * 64 if run_id == "G1-0000" else "2" * 64
        child_package = self.prior if run_id == "G1-0000" else self.continuation
        child = json.loads(
            (child_package / "children" / f"{run_id}.json").read_text(encoding="utf-8")
        )
        archive = self.archives / f"{run_id}_{manifest_sha}.tar.gz"
        marker = self.archives / f"{run_id}_{manifest_sha}.ARCHIVED.json"
        archive.unlink()
        marker.unlink()
        spool = self.root / f"spool-{run_id}"
        rmtree(spool)
        spool.mkdir()
        configuration = child["configuration_start"]
        (spool / f"{configuration}_KINGEA_STAGE12_COMPLETE_{configuration}.frame").write_text(
            f"config={configuration}|branch={child['branch']}|partition={child['partition']}|"
            "entries=1|exits=1|missed=0|delay_expiry=0|gate_reject_after_delay=0|"
            "virtual_execution_failure=0|hard_failures=0|complete=1|"
            "trade_returns=0.100000000000|trade_r=1.000000000000|"
            "daily_returns=0.100000000000",
            encoding="utf-8",
        )
        event_root = "E" * 64
        (spool / f"{configuration}_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame").write_text(
            "schema=1|sequence=1|event_id=CLOSE|2021.07.01 00:00:00|event_type=9|server_time_msc=1|"
            "sleeve=SLEEVE-1|group=GROUP-1|order=1|deal=1|position=1|"
            "gross=100.000000000000|commission=0.000000000000|"
            "swap=0.000000000000|fee=0.000000000000|net=100.000000000000|"
            f"net_return={stage13_return}|net_r=1.000000000000|"
            "mae_r=0.500000000000|mfe_r=1.500000000000|bars_held=2|"
            f"root={event_root}",
            encoding="utf-8",
        )
        (spool / f"{configuration}_KINGEA_STAGE13_ACCOUNTING_COMPLETE_{configuration}.frame").write_text(
            "schema=1|event_count=1|close_count=1|trade_return_count=1|"
            "legacy_net=100.000000000000|ledger_net=100.000000000000|"
            f"root={event_root}|complete=1",
            encoding="utf-8",
        )
        self._archive_spool(run_id, manifest_sha, spool)

    def rewrite_with_local_pass_number(self, run_id: str, local_pass: int):
        manifest_sha = "1" * 64 if run_id == "G1-0000" else "2" * 64
        spool = self.root / f"spool-{run_id}"
        for path in list(spool.iterdir()):
            global_configuration = path.name.split("_", 1)[0]
            path.rename(path.with_name(f"{local_pass}_{path.name[len(global_configuration) + 1:]}"))
        (self.archives / f"{run_id}_{manifest_sha}.tar.gz").unlink()
        (self.archives / f"{run_id}_{manifest_sha}.ARCHIVED.json").unlink()
        self._archive_spool(run_id, manifest_sha, spool)

    def add_repeated_ledger_root(self, run_id: str):
        self.rewrite_with_trade(run_id, stage13_return="0.100000000000")
        manifest_sha = "1" * 64 if run_id == "G1-0000" else "2" * 64
        spool = self.root / f"spool-{run_id}"
        configuration = 0 if run_id == "G1-0000" else 1
        root = "E" * 64
        (spool / f"{configuration}_KINGEA_STAGE13_ACCOUNTING_EVENT_2.frame").write_text(
            "schema=1|sequence=2|event_id=DAY|2021.07.02 00:00:00|event_type=6|"
            "server_time_msc=2|sleeve=SLEEVE-1|group=|order=0|deal=0|position=0|"
            "gross=0.000000000000|commission=0.000000000000|swap=0.000000000000|"
            "fee=0.000000000000|net=0.000000000000|net_return=0.000000000000|"
            "net_r=0.000000000000|mae_r=0.000000000000|mfe_r=0.000000000000|"
            f"bars_held=0|root={root}",
            encoding="utf-8",
        )
        complete = spool / f"{configuration}_KINGEA_STAGE13_ACCOUNTING_COMPLETE_{configuration}.frame"
        complete.write_text(
            "schema=1|event_count=2|close_count=1|trade_return_count=1|"
            "legacy_net=100.000000000000|ledger_net=100.000000000000|"
            f"root={root}|complete=1",
            encoding="utf-8",
        )
        (self.archives / f"{run_id}_{manifest_sha}.tar.gz").unlink()
        (self.archives / f"{run_id}_{manifest_sha}.ARCHIVED.json").unlink()
        self._archive_spool(run_id, manifest_sha, spool)

    def remove_accounting_event_field(self, run_id: str, field: str):
        self.rewrite_with_trade(run_id, stage13_return="0.100000000000")
        manifest_sha = "1" * 64 if run_id == "G1-0000" else "2" * 64
        spool = self.root / f"spool-{run_id}"
        configuration = 0 if run_id == "G1-0000" else 1
        event = spool / f"{configuration}_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame"
        parts = [part for part in event.read_text(encoding="utf-8").split("|") if not part.startswith(field + "=")]
        event.write_text("|".join(parts), encoding="utf-8")
        (self.archives / f"{run_id}_{manifest_sha}.tar.gz").unlink()
        (self.archives / f"{run_id}_{manifest_sha}.ARCHIVED.json").unlink()
        self._archive_spool(run_id, manifest_sha, spool)

    def _archive_spool(self, run_id: str, manifest_sha: str, spool: Path):
        archive = self.archives / f"{run_id}_{manifest_sha}.tar.gz"
        with tarfile.open(archive, "w:gz") as handle:
            for path in sorted(spool.iterdir()):
                handle.add(path, arcname=f"./{path.name}")
        rows = sorted((path.name, path.stat().st_size) for path in spool.iterdir())
        metadata = hashlib.sha256()
        samples = {}
        for name, size in rows:
            metadata.update(name.encode() + b"\0" + str(size).encode() + b"\n")
            samples[name] = hashlib.sha256((spool / name).read_bytes()).hexdigest().upper()
        marker = {
            "schema": 1,
            "status": "ARCHIVED_VERIFIED",
            "run_id": run_id,
            "manifest_sha256": manifest_sha,
            "file_count": len(rows),
            "logical_bytes": sum(size for _, size in rows),
            "metadata_sha256": metadata.hexdigest().upper(),
            "sample_count": len(samples),
            "sample_set_sha256": hashlib.sha256(
                json.dumps(samples, sort_keys=True).encode()
            ).hexdigest().upper(),
            "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest().upper(),
            "archive_path": str(archive),
            "loose_files_removed": True,
        }
        (self.archives / f"{run_id}_{manifest_sha}.ARCHIVED.json").write_text(
            json.dumps(marker), encoding="utf-8"
        )


class Gate1FinalizerTests(unittest.TestCase):
    def test_historical_audit_scope_is_exact_and_capability_is_integrity_only(self):
        with self.assertRaisesRegex(
            HistoricalAuditIntegrityError, "HISTORICAL_AUDIT_SCOPE_UNKNOWN"
        ):
            RetiredHistoricalGate1Audit(HistoricalAuditScope(
                scope_id="UNKNOWN_HISTORY", schema_version=1,
                record_identity="A" * 64,
            ))

        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            audit = fixture.historical_audit()
            capabilities = audit.specification["capabilities"]
            self.assertTrue(capabilities["integrity_verification"])
            for name, allowed in capabilities.items():
                if name != "integrity_verification":
                    self.assertFalse(allowed, name)
            for prohibited in (
                "authorize", "render_bundle", "prepare_gate_root",
                "materialize_children", "select", "freeze",
            ):
                self.assertFalse(hasattr(audit, prohibited), prohibited)

            wrong = RetiredHistoricalGate1Audit(HistoricalAuditScope(
                scope_id="RETIRED_GATE1_TEST_FIXTURE", schema_version=1,
                record_identity="F" * 64,
            ))
            with self.assertRaisesRegex(
                HistoricalAuditIntegrityError, "HISTORICAL_AUDIT_RECORD_MISMATCH"
            ):
                wrong.finalize(fixture.request())

    def test_successor_candidate_cannot_request_historical_audit_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            for package in (fixture.prior, fixture.continuation):
                path = package / "GATE1_ROOT.json"
                value = json.loads(path.read_text(encoding="utf-8"))
                value["candidate_id"] = "CAND-ETH-ST-002"
                path.write_text(json.dumps(value), encoding="utf-8")
            request = fixture.request()
            audit = RetiredHistoricalGate1Audit(HistoricalAuditScope(
                scope_id="RETIRED_GATE1_TEST_FIXTURE", schema_version=1,
                record_identity=Gate1Finalizer.historical_record_identity(request),
            ))
            with self.assertRaisesRegex(
                HistoricalAuditIntegrityError, "HISTORICAL_AUDIT_SCOPE_MISMATCH"
            ):
                audit.finalize(request)

    def test_finalization_contract_is_nonexecuting_and_fail_closed(self):
        workspace = Path(__file__).resolve().parents[1]
        contract = json.loads(
            (workspace / "governance" / "stage14_gate1_finalization_contract.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual("GATE1_STREAMING_FINALIZATION", contract["kind"])
        self.assertFalse(contract["capabilities"]["mt5_launch"])
        self.assertFalse(contract["capabilities"]["order_execution"])
        self.assertFalse(contract["capabilities"]["network"])
        self.assertFalse(contract["capabilities"]["oos_access"])
        self.assertFalse(contract["capabilities"]["holdout_access"])
        self.assertEqual(0, contract["candidate_budget_increment"])
        self.assertEqual(20, contract["resumable_audit"]["archives_per_batch"])
        self.assertEqual(10, contract["resumable_audit"]["governed_batch_count"])
        self.assertTrue(contract["resumable_audit"]["shards_append_only"])
        sources = [
            workspace / "research_pipeline" / "gate1_finalization.py",
            workspace / "research_pipeline" / "gate1_finalization_cli.py",
            workspace / "operations" / "Finalize-Gate1.ps1",
            workspace / "operations" / "Start-Gate1FinalizationBatches.ps1",
        ]
        forbidden = (
            "subprocess",
            "os.system",
            "start-process",
            "terminal64",
            "ordersend",
            "webrequest",
            "#import",
            "requests.",
            "urllib",
            "socket",
        )
        for source in sources:
            text = source.read_text(encoding="utf-8").lower()
            for token in forbidden:
                self.assertNotIn(token, text, f"{token} found in {source}")

    def test_all_zero_two_epoch_evidence_is_quarantined_without_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            result = fixture.historical_audit().finalize(fixture.request())

            self.assertEqual("RETIRED_HISTORICAL_AUDIT_PASS", result["status"])
            self.assertEqual(
                "QUARANTINED_PENDING_DIAGNOSTIC",
                result["historical_classification"],
            )
            self.assertEqual(2, result["evaluated_configuration_count"])
            self.assertEqual(0, result["entry_count"])
            self.assertEqual(0, result["candidate_budget_consumed"])
            self.assertEqual(
                canonical_hash(
                    {key: value for key, value in result.items() if key != "result_sha256"}
                ),
                result["result_sha256"],
            )
            self.assertFalse((fixture.output / "selections").exists())
            self.assertFalse((fixture.output / "gate2").exists())
            self.assertFalse(result["research_root_created"])
            self.assertFalse(result["selection_emitted"])
            self.assertFalse(result["gate2_prepared"])

    def test_one_digit_stage12_stage13_trade_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            fixture.rewrite_with_trade("G1-0000", stage13_return="0.100000000001")

            with self.assertRaisesRegex(ValueError, "ACCOUNTING_NET_RETURN_MISMATCH"):
                fixture.historical_audit().finalize(fixture.request())

    def test_failed_build_parity_cannot_join_the_two_epochs(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            path = fixture.parity / "PARITY_RESULT.json"
            parity = json.loads(path.read_text(encoding="utf-8"))
            parity["status"] = "FAIL"
            parity["result_sha256"] = canonical_hash(
                {key: value for key, value in parity.items() if key != "result_sha256"}
            )
            path.write_text(json.dumps(parity), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "BUILD_PARITY_NOT_ACCEPTABLE"):
                fixture.historical_audit().finalize(fixture.request())

    def test_unexplained_extra_archive_quarantines_finalization(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            with tarfile.open(fixture.archives / "UNEXPLAINED.tar.gz", "w:gz"):
                pass

            with self.assertRaisesRegex(ValueError, "UNEXPLAINED_EXTRA_ARCHIVE"):
                fixture.historical_audit().finalize(fixture.request())

    def test_child_manifest_file_hash_is_part_of_lineage(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            path = fixture.prior / "children" / "G1-0000.json"
            child = json.loads(path.read_text(encoding="utf-8"))
            child["branch"] = "RSB3"
            path.write_text(json.dumps(child), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "CHILD_FILE_HASH_MISMATCH"):
                fixture.historical_audit().finalize(fixture.request())

    def test_completed_inventory_rows_must_match_the_prior_epoch(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            path = fixture.continuation / "COMPLETED_EVIDENCE_INVENTORY.json"
            inventory = json.loads(path.read_text(encoding="utf-8"))
            inventory["rows"][0]["manifest_sha256"] = "F" * 64
            inventory["inventory_sha256"] = canonical_hash(
                {
                    key: value
                    for key, value in inventory.items()
                    if key != "inventory_sha256"
                }
            )
            path.write_text(json.dumps(inventory), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "COMPLETED_INVENTORY_ROW_CONFLICT"):
                fixture.historical_audit().finalize(fixture.request())

    def test_failed_nested_parity_comparison_cannot_hide_behind_pass_result(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            path = fixture.parity / "PARITY_RESULT.json"
            parity = json.loads(path.read_text(encoding="utf-8"))
            parity["comparisons"] = [
                {
                    "reference_run_id": "G1-0000",
                    "new_mt5_build": 6140,
                    "status": "FAIL",
                }
            ]
            parity["comparison_count"] = 1
            parity["result_sha256"] = canonical_hash(
                {key: value for key, value in parity.items() if key != "result_sha256"}
            )
            path.write_text(json.dumps(parity), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "BUILD_PARITY_COMPARISON_INVALID"):
                fixture.historical_audit().finalize(fixture.request())

    def test_chunk_local_pass_number_may_differ_from_global_configuration_id(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            fixture.rewrite_with_local_pass_number("G1-0001", 0)

            result = fixture.historical_audit().finalize(fixture.request())

            self.assertEqual("RETIRED_HISTORICAL_AUDIT_PASS", result["status"])
            self.assertEqual(2, result["evaluated_configuration_count"])

    def test_streaming_progress_reports_each_verified_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            updates = []
            request = fixture.request()
            request = Gate1FinalizationRequest(
                prior_package=request.prior_package,
                continuation_package=request.continuation_package,
                parity_package=request.parity_package,
                archive_root=request.archive_root,
                execution_root=request.execution_root,
                output_root=request.output_root,
                allow_test_fixture=True,
                progress_callback=updates.append,
            )

            fixture.historical_audit().finalize(request)

            self.assertEqual(["G1-0000", "G1-0001"], [row["run_id"] for row in updates])
            self.assertEqual([1, 2], [row["completed_archives"] for row in updates])

    def test_repeated_event_root_breaks_the_ledger_chain(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            fixture.add_repeated_ledger_root("G1-0000")

            with self.assertRaisesRegex(ValueError, "ACCOUNTING_LEDGER_ROOT_REPEAT"):
                fixture.historical_audit().finalize(fixture.request())

    def test_partial_accounting_event_is_not_a_complete_sequence(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            fixture.remove_accounting_event_field("G1-0000", "fee")

            with self.assertRaisesRegex(ValueError, "ACCOUNTING_EVENT_SCHEMA_INVALID"):
                fixture.historical_audit().finalize(fixture.request())

    def test_batches_resume_without_rewriting_and_merge_to_the_same_quarantine(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            finalizer = fixture.historical_audit()
            shards = Path(directory) / "shards"
            first = finalizer.audit_batch(fixture.request(), shards, 1, batch_size=1)
            again = finalizer.audit_batch(fixture.request(), shards, 1, batch_size=1)
            second = finalizer.audit_batch(fixture.request(), shards, 2, batch_size=1)

            self.assertEqual("COMPLETE", first["status"])
            self.assertEqual("COMPLETE_EXISTING", again["status"])
            self.assertEqual("COMPLETE", second["status"])
            result = finalizer.merge_batches(fixture.request(), shards, batch_size=1)
            self.assertEqual("RETIRED_HISTORICAL_AUDIT_PASS", result["status"])
            self.assertEqual(2, result["evaluated_configuration_count"])

    def test_batch_merge_rejects_tampered_or_missing_shards(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            finalizer = fixture.historical_audit()
            shards = Path(directory) / "shards"
            finalizer.audit_batch(fixture.request(), shards, 1, batch_size=1)
            with self.assertRaisesRegex(ValueError, "AUDIT_SHARD_SET_INCOMPLETE"):
                finalizer.merge_batches(fixture.request(), shards, batch_size=1)

            finalizer.audit_batch(fixture.request(), shards, 2, batch_size=1)
            path = shards / "BATCH-02.json"
            shard = json.loads(path.read_text(encoding="utf-8"))
            shard["results"][0]["entries"] = 1
            path.write_text(json.dumps(shard), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "AUDIT_SHARD_HASH_MISMATCH"):
                finalizer.merge_batches(fixture.request(), shards, batch_size=1)

    def test_batch_status_discovers_only_the_next_unfinished_batch(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            finalizer = fixture.historical_audit()
            shards = Path(directory) / "shards"
            before = finalizer.batch_status(fixture.request(), shards, batch_size=1)
            self.assertEqual([1, 2], before["remaining_batches"])
            self.assertEqual(1, before["next_batch_id"])

            finalizer.audit_batch(fixture.request(), shards, 1, batch_size=1)
            after = finalizer.batch_status(fixture.request(), shards, batch_size=1)
            self.assertEqual([1], after["completed_batches"])
            self.assertEqual([2], after["remaining_batches"])
            self.assertEqual(2, after["next_batch_id"])

    def test_merged_shards_match_the_single_stream_audit_outcome(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            direct_fixture = FinalizationFixture(root / "direct")
            direct = direct_fixture.historical_audit().finalize(direct_fixture.request())

            batch_fixture = FinalizationFixture(root / "batched")
            finalizer = batch_fixture.historical_audit()
            shards = root / "batched-shards"
            finalizer.audit_batch(batch_fixture.request(), shards, 1, batch_size=1)
            finalizer.audit_batch(batch_fixture.request(), shards, 2, batch_size=1)
            merged = finalizer.merge_batches(batch_fixture.request(), shards, batch_size=1)

            for field in (
                "status",
                "evaluated_configuration_count",
                "entry_count",
                "exit_count",
                "trade_group_count",
                "hard_failure_count",
                "candidate_budget_consumed",
            ):
                self.assertEqual(direct[field], merged[field], field)

    def test_merge_rejects_rehashed_wrong_epoch_or_mixed_lineage_shard(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FinalizationFixture(Path(directory))
            finalizer = fixture.historical_audit()
            shards = Path(directory) / "shards"
            finalizer.audit_batch(fixture.request(), shards, 1, batch_size=1)
            finalizer.audit_batch(fixture.request(), shards, 2, batch_size=1)
            path = shards / "BATCH-02.json"
            shard = json.loads(path.read_text(encoding="utf-8"))
            shard["epochs"] = [0]
            shard["shard_sha256"] = canonical_hash(
                {key: value for key, value in shard.items() if key != "shard_sha256"}
            )
            path.write_text(json.dumps(shard), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "AUDIT_SHARD_CONTENT_CONFLICT"):
                finalizer.merge_batches(fixture.request(), shards, batch_size=1)


if __name__ == "__main__":
    unittest.main()
