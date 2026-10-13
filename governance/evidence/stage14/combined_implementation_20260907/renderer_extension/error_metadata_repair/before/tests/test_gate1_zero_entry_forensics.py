import hashlib
import json
import tarfile
import tempfile
import unittest
from pathlib import Path

from research_pipeline.gate1_zero_entry_forensics import Gate1ZeroEntryForensics


def write_archive(path: Path, frames: dict[str, str]) -> str:
    source = path.parent / "source"
    source.mkdir(exist_ok=True)
    for name, value in frames.items():
        (source / name).write_text(value, encoding="utf-8")
    with tarfile.open(path, "w:gz") as archive:
        for name in sorted(frames):
            archive.add(source / name, arcname=f"./{name}")
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def accounting_event(sequence: int, event_type: int, root: str, *, time: int | None = None) -> str:
    return (
        f"schema=1|sequence={sequence}|event_id=E{sequence}|event_type={event_type}|"
        f"server_time_msc={time or sequence}|sleeve=SLEEVE-1|group=|order=0|deal=0|position=0|"
        "gross=0.000000000000|commission=0.000000000000|swap=0.000000000000|fee=0.000000000000|"
        "net=0.000000000000|net_return=0.000000000000|net_r=0.000000000000|"
        "mae_r=0.000000000000|mfe_r=0.000000000000|bars_held=0|root=" + root
    )


def accounting_complete(count: int, root: str) -> str:
    return (f"schema=1|event_count={count}|close_count=0|trade_return_count=0|"
            f"legacy_net=0.000000000000|ledger_net=0.000000000000|root={root}|complete=1")


class Gate1ZeroEntryForensicsTests(unittest.TestCase):
    @staticmethod
    def stage13_child():
        return {"run_id":"G1-0000","manifest_sha256":"A"*64,"branch":"RECORDED",
                "partition":"FOLD_1_TRAIN","configuration_start":0,"configuration_end":0}

    @staticmethod
    def stage13_marker(root: Path, frames: dict[str, str], *, manifest="A" * 64, archive_sha=None):
        archive = root / "G1-0000_A.tar.gz"; digest = write_archive(archive, frames)
        marker = root / "G1-0000_A.ARCHIVED.json"
        marker.write_text(json.dumps({"status":"ARCHIVED_VERIFIED","run_id":"G1-0000","manifest_sha256":manifest,
            "archive_path":str(archive),"archive_sha256":archive_sha or digest}), encoding="utf-8")
        return marker
    def test_partial_g1_0037_is_excluded_and_accepted_retry_is_scanned(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            archive_root = root / "archives"
            archive_root.mkdir()
            accepted = archive_root / "G1-0037_A.tar.gz"
            accepted_hash = write_archive(accepted, {
                "0_KINGEA_STAGE12_COMPLETE_17000.frame": "config=17000|branch=RSB3|partition=FOLD_1_TRAIN|entries=0|exits=0|hard_failures=0|complete=1"
            })
            (archive_root / "G1-0037_A.ARCHIVED.json").write_text(json.dumps({
                "schema": 1, "status": "ARCHIVED_VERIFIED", "run_id": "G1-0037",
                "manifest_sha256": "A" * 64, "archive_path": str(accepted),
                "archive_sha256": accepted_hash,
            }), encoding="utf-8")
            partial = archive_root / "G1-0037_A_INVALIDATED.tar.gz"
            write_archive(partial, {
                "0_KINGEA_STAGE12_COMPLETE_17000.frame": "config=17000|branch=RSB3|partition=FOLD_1_TRAIN|entries=0|exits=0|hard_failures=0|complete=1"
            })
            result = Gate1ZeroEntryForensics().scan_archive(
                archive_root / "G1-0037_A.ARCHIVED.json",
                {"run_id": "G1-0037", "manifest_sha256": "A" * 64,
                 "branch": "RSB3", "partition": "FOLD_1_TRAIN",
                 "configuration_start": 17000, "configuration_end": 17000},
            )
            self.assertEqual(1, result["stage12_frames"])
            self.assertEqual(0, result["entries"])
            self.assertTrue(result["invalidated_partial_present"])
            self.assertEqual(0, result["launch_artifacts"])

    def test_rejects_partial_marker_as_accepted_or_frame_scope_mismatch(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            archive = root / "G1-0000_INVALIDATED.tar.gz"
            sha = write_archive(archive, {
                "0_KINGEA_STAGE12_COMPLETE_0.frame": "config=0|branch=RECORDED|partition=FOLD_1_TRAIN|entries=0|exits=0|hard_failures=0|complete=1"
            })
            marker = root / "G1-0000_INVALIDATED.ARCHIVED.json"
            marker.write_text(json.dumps({"status": "ARCHIVED_VERIFIED", "run_id": "G1-0000", "manifest_sha256": "A" * 64, "archive_path": str(archive), "archive_sha256": sha}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "INVALIDATED_ARCHIVE_NOT_ACCEPTED"):
                Gate1ZeroEntryForensics().scan_archive(marker, {"run_id": "G1-0000", "manifest_sha256": "A" * 64, "branch": "RECORDED", "partition": "FOLD_1_TRAIN", "configuration_start": 0, "configuration_end": 999})

    def test_stage13_summary_detects_retained_valuation_only_boundary(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            archive = root / "G1-0000_A.tar.gz"
            frame = (
                "schema=1|sequence=1|event_id=DAY|2021.07.01 00:00:00|event_type=6|"
                "server_time_msc=1|sleeve=SLEEVE-1|group=|order=0|deal=0|position=0|"
                "gross=0.000000000000|commission=0.000000000000|swap=0.000000000000|"
                "fee=0.000000000000|net=0.000000000000|net_return=0.000000000000|"
                "net_r=0.000000000000|mae_r=0.000000000000|mfe_r=0.000000000000|"
                "bars_held=0|root=" + "A" * 64
            )
            archive_hash = write_archive(archive, {
                "0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame": frame,
                "0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame": (
                    "schema=1|event_count=1|close_count=0|trade_return_count=0|"
                    "legacy_net=0.000000000000|ledger_net=0.000000000000|root=" + "A" * 64 + "|complete=1"
                ),
            })
            marker = root / "G1-0000_A.ARCHIVED.json"
            marker.write_text(json.dumps({"status": "ARCHIVED_VERIFIED", "run_id": "G1-0000",
                "manifest_sha256": "A" * 64, "archive_path": str(archive), "archive_sha256": archive_hash}), encoding="utf-8")
            result = Gate1ZeroEntryForensics().scan_stage13_archive(marker, {
                "run_id": "G1-0000", "manifest_sha256": "A" * 64, "branch": "RECORDED",
                "partition": "FOLD_1_TRAIN", "configuration_start": 0, "configuration_end": 0,
            })
            self.assertEqual("VALID", result["integrity"])
            self.assertEqual({"6": 1}, result["event_type_counts"])
            self.assertEqual("ALL_CONFIGURATIONS_VALUATION_ONLY", result["retained_boundary"])
            self.assertEqual({"VALUATION_ONLY": 1}, result["configuration_class_counts"])
            self.assertEqual({"ROOT_BINDING_VALID": 1}, result["root_binding_counts"])

    def test_stage13_rejects_marker_manifest_mismatch(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); archive = root / "G1-0000_A.tar.gz"
            digest = write_archive(archive, {})
            marker = root / "G1-0000_A.ARCHIVED.json"
            marker.write_text(json.dumps({"status": "ARCHIVED_VERIFIED", "run_id": "G1-0000",
                "manifest_sha256": "B" * 64, "archive_path": str(archive), "archive_sha256": digest}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "ARCHIVE_MARKER_CONFLICT"):
                Gate1ZeroEntryForensics().scan_stage13_archive(marker, {"run_id": "G1-0000", "manifest_sha256": "A" * 64,
                    "branch": "RECORDED", "partition": "FOLD_1_TRAIN", "configuration_start": 0, "configuration_end": 0})

    def test_stage13_accepts_the_producer_zero_event_empty_root_contract(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); archive = root / "G1-0000_A.tar.gz"
            digest = write_archive(archive, {"0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame":
                "schema=1|event_count=0|close_count=0|trade_return_count=0|legacy_net=0.000000000000|ledger_net=0.000000000000|root=|complete=1"})
            marker = root / "G1-0000_A.ARCHIVED.json"
            marker.write_text(json.dumps({"status":"ARCHIVED_VERIFIED","run_id":"G1-0000","manifest_sha256":"A"*64,"archive_path":str(archive),"archive_sha256":digest}), encoding="utf-8")
            result = Gate1ZeroEntryForensics().scan_stage13_archive(marker, {"run_id":"G1-0000","manifest_sha256":"A"*64,"branch":"RECORDED","partition":"FOLD_1_TRAIN","configuration_start":0,"configuration_end":0})
            self.assertEqual({}, result["event_type_counts"])
            self.assertEqual({"ZERO_EVENT_COMPLETION": 1}, result["configuration_class_counts"])

    def test_stage13_rejects_zero_event_nonempty_root_and_missing_completion(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); archive = root / "G1-0000_A.tar.gz"
            digest = write_archive(archive, {"0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame":
                "schema=1|event_count=0|close_count=0|trade_return_count=0|legacy_net=0.000000000000|ledger_net=0.000000000000|root=" + "A" * 64 + "|complete=1"})
            marker = root / "G1-0000_A.ARCHIVED.json"
            marker.write_text(json.dumps({"status":"ARCHIVED_VERIFIED","run_id":"G1-0000","manifest_sha256":"A"*64,"archive_path":str(archive),"archive_sha256":digest}), encoding="utf-8")
            child={"run_id":"G1-0000","manifest_sha256":"A"*64,"branch":"RECORDED","partition":"FOLD_1_TRAIN","configuration_start":0,"configuration_end":0}
            with self.assertRaisesRegex(ValueError, "STAGE13_EMPTY_ROOT_CONFLICT"):
                Gate1ZeroEntryForensics().scan_stage13_archive(marker, child)

    def test_stage13_rejects_archive_hash_and_missing_completion(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); marker = self.stage13_marker(root, {}, archive_sha="B" * 64)
            with self.assertRaisesRegex(ValueError, "ARCHIVE_HASH_MISMATCH"):
                Gate1ZeroEntryForensics().scan_stage13_archive(marker, self.stage13_child())
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); marker = self.stage13_marker(root, {"0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame": accounting_event(1, 6, "A" * 64)})
            with self.assertRaisesRegex(ValueError, "STAGE13_COMPLETE_MISSING"):
                Gate1ZeroEntryForensics().scan_stage13_archive(marker, self.stage13_child())

    def test_stage13_rejects_missing_sequence_timestamp_regression_and_final_root_mismatch(self):
        cases = [
            ({"0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame": accounting_event(1, 6, "A"*64),
              "0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame": accounting_complete(2, "A"*64)}, "STAGE13_EVENT_SEQUENCE_INVALID"),
            ({"0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame": accounting_event(1, 6, "A"*64, time=2),
              "0_KINGEA_STAGE13_ACCOUNTING_EVENT_2.frame": accounting_event(2, 6, "B"*64, time=1),
              "0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame": accounting_complete(2, "B"*64)}, "STAGE13_CHAIN_ORDER_OR_ROOT_INVALID"),
            ({"0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame": accounting_event(1, 6, "A"*64),
              "0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame": accounting_complete(1, "B"*64)}, "STAGE13_FINAL_ROOT_MISMATCH"),
        ]
        for frames, error in cases:
            with self.subTest(error=error), tempfile.TemporaryDirectory() as raw:
                marker=self.stage13_marker(Path(raw),frames)
                with self.assertRaisesRegex(ValueError,error):
                    Gate1ZeroEntryForensics().scan_stage13_archive(marker,self.stage13_child())

    def test_stage13_marks_unknown_type_and_trade_type_without_performance_interpretation(self):
        for event_type, expected in ((10,"EVENT_TYPE_SEMANTICS_NOT_AFFIRMATIVELY_BOUND"),(2,"RETAINED_STAGE13_TRADE_OR_ROUTING_ACTIVITY_PRESENT")):
            with self.subTest(event_type=event_type), tempfile.TemporaryDirectory() as raw:
                root=Path(raw); event_root="A"*64
                marker=self.stage13_marker(root,{"0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame":accounting_event(1,event_type,event_root),
                    "0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame":accounting_complete(1,event_root)})
                value=Gate1ZeroEntryForensics().scan_stage13_archive(marker,self.stage13_child())
                self.assertEqual(expected,value["retained_boundary"])

    def test_stage13_rejects_duplicate_member_sequence(self):
        with tempfile.TemporaryDirectory() as raw:
            root=Path(raw); source=root/"frame"; source.write_text(accounting_event(1,6,"A"*64),encoding="utf-8")
            archive=root/"G1-0000_A.tar.gz"
            with tarfile.open(archive,"w:gz") as bundle:
                bundle.add(source,arcname="./0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame")
                bundle.add(source,arcname="./0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame")
                complete=root/"complete"; complete.write_text(accounting_complete(1,"A"*64),encoding="utf-8")
                bundle.add(complete,arcname="./0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame")
            marker=root/"G1-0000_A.ARCHIVED.json"
            marker.write_text(json.dumps({"status":"ARCHIVED_VERIFIED","run_id":"G1-0000","manifest_sha256":"A"*64,
                "archive_path":str(archive),"archive_sha256":hashlib.sha256(archive.read_bytes()).hexdigest().upper()}),encoding="utf-8")
            with self.assertRaisesRegex(ValueError,"ARCHIVE_MEMBER_DUPLICATE_OR_UNORDERED"):
                Gate1ZeroEntryForensics().scan_stage13_archive(marker,self.stage13_child())

    def test_stage13_classifies_each_configuration_without_aggregation_loss(self):
        with tempfile.TemporaryDirectory() as raw:
            root=Path(raw); trade_root="A"*64
            marker=self.stage13_marker(root,{
                "0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame":accounting_complete(0,""),
                "1_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame":accounting_event(1,2,trade_root),
                "1_KINGEA_STAGE13_ACCOUNTING_COMPLETE_1.frame":accounting_complete(1,trade_root),
            })
            child=dict(self.stage13_child()); child["configuration_end"]=1
            value=Gate1ZeroEntryForensics().scan_stage13_archive(marker,child)
            self.assertEqual({"ZERO_EVENT_COMPLETION":1,"TRADE_OR_ROUTING_ACTIVITY_PRESENT":1},value["configuration_class_counts"])
            self.assertEqual({"TRADE_OR_ROUTING_ACTIVITY_PRESENT":[1]},value["configuration_ids_by_class"])
            self.assertEqual("RETAINED_STAGE13_TRADE_OR_ROUTING_ACTIVITY_PRESENT",value["retained_boundary"])
