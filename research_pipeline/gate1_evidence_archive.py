from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import tarfile
from pathlib import Path


class EvidenceArchiveError(ValueError):
    pass


class Gate1EvidenceArchive:
    """Losslessly consolidate completed Gate 1 spool trees behind one interface."""

    def __init__(self, execution_root: Path, spool_root: Path, archive_root: Path):
        self.execution_root = Path(execution_root).resolve()
        self.spool_root = Path(spool_root).resolve()
        self.archive_root = Path(archive_root).resolve()

    @staticmethod
    def _read(path: Path) -> dict:
        return json.loads(path.read_text(encoding="utf-8"))

    @staticmethod
    def _tree_digest_from_directory(root: Path) -> tuple[str, int, int]:
        digest = hashlib.sha256()
        count = total = 0
        for path in sorted((p for p in root.rglob("*") if p.is_file()), key=lambda p: p.relative_to(root).as_posix()):
            relative = path.relative_to(root).as_posix()
            data = path.read_bytes()
            digest.update(relative.encode("utf-8") + b"\0")
            digest.update(str(len(data)).encode("ascii") + b"\0" + data)
            count += 1
            total += len(data)
        return digest.hexdigest().upper(), count, total

    @staticmethod
    def _tree_digest_from_archive(archive: Path) -> tuple[str, int, int]:
        digest = hashlib.sha256()
        count = total = 0
        with tarfile.open(archive, "r:gz") as handle:
            members = sorted((m for m in handle.getmembers() if m.isfile()), key=lambda m: m.name)
            for member in members:
                if Path(member.name).is_absolute() or ".." in Path(member.name).parts:
                    raise EvidenceArchiveError("UNSAFE_ARCHIVE_MEMBER")
                stream = handle.extractfile(member)
                if stream is None:
                    raise EvidenceArchiveError("ARCHIVE_MEMBER_UNREADABLE")
                data = stream.read()
                digest.update(member.name.encode("utf-8") + b"\0")
                digest.update(str(len(data)).encode("ascii") + b"\0" + data)
                count += 1
                total += len(data)
        return digest.hexdigest().upper(), count, total

    @staticmethod
    def _metadata_digest(rows: list[tuple[str, int]]) -> str:
        digest = hashlib.sha256()
        for name, size in rows:
            digest.update(name.encode("utf-8") + b"\0" + str(size).encode("ascii") + b"\n")
        return digest.hexdigest().upper()

    @staticmethod
    def _sample_indexes(count: int) -> list[int]:
        if count <= 128:
            return list(range(count))
        return sorted({round(index * (count - 1) / 127) for index in range(128)})

    def _create_verified_archive(self, spool: Path, archive: Path) -> dict:
        rows = sorted(
            ((path.relative_to(spool).as_posix(), path.stat().st_size)
             for path in spool.iterdir() if path.is_file()),
            key=lambda row: row[0],
        )
        if not rows:
            raise EvidenceArchiveError("SPOOL_EMPTY")
        indexes = self._sample_indexes(len(rows))
        source_samples = {
            rows[index][0]: hashlib.sha256((spool / rows[index][0]).read_bytes()).hexdigest().upper()
            for index in indexes
        }
        partial = archive.with_suffix(archive.suffix + ".partial")
        completed = subprocess.run(
            ["tar.exe", "-czf", str(partial), "-C", str(spool), "."],
            capture_output=True, text=True, check=False,
        )
        if completed.returncode != 0:
            raise EvidenceArchiveError(f"TAR_CREATE_FAILED:{completed.stderr.strip()}")
        partial.replace(archive)
        archive_rows: list[tuple[str, int]] = []
        archive_samples: dict[str, str] = {}
        with tarfile.open(archive, "r:gz") as handle:
            members = []
            for member in handle.getmembers():
                if not member.isfile():
                    continue
                name = member.name[2:] if member.name.startswith("./") else member.name
                if Path(name).is_absolute() or ".." in Path(name).parts:
                    raise EvidenceArchiveError("UNSAFE_ARCHIVE_MEMBER")
                members.append((name, member.size, member))
            members.sort(key=lambda row: row[0])
            archive_rows = [(name, size) for name, size, _ in members]
            selected = set(source_samples)
            for name, _, member in members:
                if name in selected:
                    stream = handle.extractfile(member)
                    archive_samples[name] = hashlib.sha256(stream.read()).hexdigest().upper()
        if rows != archive_rows:
            raise EvidenceArchiveError("ARCHIVE_METADATA_READBACK_MISMATCH")
        if source_samples != archive_samples:
            raise EvidenceArchiveError("ARCHIVE_CONTENT_SAMPLE_MISMATCH")
        return {
            "file_count": len(rows), "logical_bytes": sum(size for _, size in rows),
            "metadata_sha256": self._metadata_digest(rows),
            "sample_count": len(source_samples),
            "sample_set_sha256": hashlib.sha256(json.dumps(source_samples, sort_keys=True).encode()).hexdigest().upper(),
        }

    def _paths_for_completed(self, run_id: str) -> tuple[dict, Path, Path, Path]:
        marker = self.execution_root / "children" / run_id / "COMPLETE.json"
        if not marker.is_file():
            raise EvidenceArchiveError("CHILD_NOT_COMPLETE")
        complete = self._read(marker)
        if complete.get("status") != "COMPLETE" or complete.get("run_id") != run_id:
            raise EvidenceArchiveError("INVALID_COMPLETION_MARKER")
        manifest_sha = str(complete.get("manifest_sha256", ""))
        spool = (self.spool_root / manifest_sha).resolve()
        if spool.parent != self.spool_root or not spool.is_dir():
            raise EvidenceArchiveError("COMPLETED_SPOOL_MISSING")
        archive = self.archive_root / f"{run_id}_{manifest_sha}.tar.gz"
        evidence = self.archive_root / f"{run_id}_{manifest_sha}.ARCHIVED.json"
        return complete, spool, archive, evidence

    def archive_completed(self, run_id: str, *, remove_verified: bool) -> dict:
        complete, spool, archive, evidence = self._paths_for_completed(run_id)
        self.archive_root.mkdir(parents=True, exist_ok=True)
        if archive.exists() or evidence.exists():
            raise EvidenceArchiveError("ARCHIVE_EVIDENCE_ALREADY_EXISTS")
        verified = self._create_verified_archive(spool, archive)
        record = {
            "schema": 1, "status": "ARCHIVED_VERIFIED", "run_id": run_id,
            "manifest_sha256": complete["manifest_sha256"], **verified,
            "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest().upper(),
            "archive_path": str(archive), "original_spool_path": str(spool),
            "loose_files_removed": bool(remove_verified),
        }
        evidence.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if remove_verified:
            shutil.rmtree(spool)
        return record

    def restore(self, run_id: str) -> dict:
        matches = list(self.archive_root.glob(f"{run_id}_*.ARCHIVED.json"))
        if len(matches) != 1:
            raise EvidenceArchiveError("ARCHIVE_RECORD_NOT_UNIQUE")
        record = self._read(matches[0])
        archive = Path(record["archive_path"])
        spool = Path(record["original_spool_path"])
        if spool.exists():
            raise EvidenceArchiveError("RESTORE_TARGET_EXISTS")
        if hashlib.sha256(archive.read_bytes()).hexdigest().upper() != record["archive_sha256"]:
            raise EvidenceArchiveError("ARCHIVE_FILE_HASH_MISMATCH")
        spool.mkdir(parents=True)
        with tarfile.open(archive, "r:gz") as handle:
            for member in handle.getmembers():
                if Path(member.name).is_absolute() or ".." in Path(member.name).parts:
                    raise EvidenceArchiveError("UNSAFE_ARCHIVE_MEMBER")
            handle.extractall(spool, filter="data")
        rows = sorted(((p.relative_to(spool).as_posix(), p.stat().st_size) for p in spool.iterdir() if p.is_file()))
        count, total = len(rows), sum(size for _, size in rows)
        if (self._metadata_digest(rows), count, total) != (record["metadata_sha256"], record["file_count"], record["logical_bytes"]):
            raise EvidenceArchiveError("RESTORED_TREE_MISMATCH")
        return {"status": "RESTORED_VERIFIED", "run_id": run_id, "file_count": count}

    def invalidate_partial(self, run_id: str, *, reason: str, last_configuration_id: int) -> dict:
        child = self.execution_root / "children" / run_id
        if (child / "COMPLETE.json").exists():
            raise EvidenceArchiveError("CANNOT_INVALIDATE_COMPLETE_CHILD")
        marker = child / "RUNNING.json"
        if not marker.is_file():
            raise EvidenceArchiveError("PARTIAL_RUNNING_MARKER_MISSING")
        running = self._read(marker)
        manifest_sha = str(running.get("manifest_sha256", ""))
        spool = (self.spool_root / manifest_sha).resolve()
        if spool.parent != self.spool_root or not spool.is_dir():
            raise EvidenceArchiveError("PARTIAL_SPOOL_MISSING")
        self.archive_root.mkdir(parents=True, exist_ok=True)
        archive = self.archive_root / f"{run_id}_{manifest_sha}_INVALIDATED.tar.gz"
        if archive.exists() or (child / "INVALIDATED_INFRASTRUCTURE.json").exists():
            raise EvidenceArchiveError("INVALIDATION_EVIDENCE_ALREADY_EXISTS")
        verified = self._create_verified_archive(spool, archive)
        record = {
            "schema": 1, "status": "INVALIDATED_INFRASTRUCTURE", "run_id": run_id,
            "reason": reason, "manifest_sha256": manifest_sha,
            "last_completed_configuration_id": int(last_configuration_id),
            "partial_file_count": verified["file_count"], **verified,
            "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest().upper(),
            "archive_path": str(archive), "loose_files_removed": True,
            "selection_eligible": False, "retry_required": True,
        }
        target = child / "INVALIDATED_INFRASTRUCTURE.json"
        target.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        shutil.rmtree(spool)
        return record

    def prepare_retry(self, run_id: str, *, batch_id: str, attempt_id: str) -> dict:
        child = (self.execution_root / "children" / run_id).resolve()
        children_root = (self.execution_root / "children").resolve()
        if child.parent != children_root or not child.is_dir():
            raise EvidenceArchiveError("PARTIAL_CHILD_DIRECTORY_MISSING")
        invalidation = child / "INVALIDATED_INFRASTRUCTURE.json"
        if not invalidation.is_file() or self._read(invalidation).get("retry_required") is not True:
            raise EvidenceArchiveError("PARTIAL_INVALIDATION_NOT_VERIFIED")
        batch = (self.execution_root / "batches" / batch_id).resolve()
        if batch.parent != (self.execution_root / "batches").resolve() or not batch.is_dir():
            raise EvidenceArchiveError("FAILED_BATCH_DIRECTORY_MISSING")
        destination = (
            self.execution_root / "invalidated_attempts" / attempt_id / "children" / run_id
        ).resolve()
        if destination.exists():
            raise EvidenceArchiveError("INVALIDATED_ATTEMPT_DESTINATION_EXISTS")
        destination.parent.mkdir(parents=True, exist_ok=True)
        batch_record = {
            "schema": 1, "status": "INVALIDATED_INFRASTRUCTURE",
            "batch_id": batch_id, "failed_run_id": run_id,
            "attempt_id": attempt_id, "reason": "MT5_AGENT_DISK_EXHAUSTION",
            "completed_sibling_results_preserved": True,
            "failed_child_results_selection_eligible": False,
            "retry_authorized": True,
        }
        batch_marker = batch / "INVALIDATED_INFRASTRUCTURE.json"
        if batch_marker.exists():
            raise EvidenceArchiveError("BATCH_INVALIDATION_ALREADY_EXISTS")
        batch_marker.write_text(json.dumps(batch_record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        shutil.move(str(child), str(destination))
        return {
            "status": "RETRY_PREPARED", "run_id": run_id,
            "attempt_id": attempt_id, "preserved_child_path": str(destination),
            "batch_invalidation_path": str(batch_marker),
        }
