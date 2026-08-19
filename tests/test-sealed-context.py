#!/usr/bin/env python3

from datetime import datetime, timezone
from pathlib import Path
import hashlib
import os
import re
import subprocess
import tempfile
import textwrap


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/build-immutable.yml"
DIGEST_PATTERN = re.compile(r"sha256:[0-9a-f]{64}")
SBOM_GENERATOR = (
    "docker/buildkit-syft-scanner@"
    "sha256:79e7b013cbec16bbb436f312819a49a4a57752b2270c1a9332ae1a10fcc82a68"
)


def extract_helper() -> str:
    lines = WORKFLOW.read_text(encoding="utf-8").splitlines()
    blocks: list[str] = []
    cursor = 0
    while cursor < len(lines):
        if "<<'PY'" not in lines[cursor]:
            cursor += 1
            continue
        start = cursor + 1
        end = start
        while end < len(lines) and lines[end].strip() != "PY":
            end += 1
        if end == len(lines):
            raise RuntimeError("unterminated Python heredoc in release workflow")
        blocks.append(textwrap.dedent("\n".join(lines[start:end])) + "\n")
        cursor = end + 1

    helpers = [block for block in blocks if "os.memfd_create" in block]
    if len(helpers) != 1:
        raise RuntimeError(f"expected one sealed-context helper, found {len(helpers)}")
    compile(helpers[0], str(WORKFLOW), "exec")
    return helpers[0]


def git(*arguments: str) -> bytes:
    return subprocess.check_output(
        ["/usr/bin/git", "-C", str(ROOT), *arguments],
    )


def sha256(payload: bytes) -> str:
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def build_command(
    source_sha: str,
    tree_sha: str,
    timestamp: str,
    epoch: str,
    build_identity: str,
) -> list[str]:
    return [
        "docker",
        "buildx",
        "build",
        "--platform",
        "linux/amd64",
        "--file",
        "Dockerfile",
        "--build-arg",
        f"OCI_REVISION={source_sha}",
        "--build-arg",
        f"OCI_VERSION={source_sha}",
        "--build-arg",
        f"OCI_CREATED={timestamp}",
        "--build-arg",
        f"OCI_SOURCE_COMMITTED_AT={timestamp}",
        "--build-arg",
        f"OCI_TREE={tree_sha}",
        "--build-arg",
        f"OCI_BUILD_ID={build_identity}",
        "--build-arg",
        f"SOURCE_DATE_EPOCH={epoch}",
        "--provenance=mode=max,version=v1",
        "--attest",
        f"type=sbom,generator={SBOM_GENERATOR}",
        "--metadata-file",
        "build-metadata.json",
        "--output",
        "type=image,name=ghcr.io/c0h1b4/pacotinho-blog,push-by-digest=true,name-canonical=true,push=true",
        "-",
    ]


def main() -> None:
    helper = extract_helper()
    source_sha = git("rev-parse", "HEAD").decode().strip()
    tree_sha = git("show", "-s", "--format=%T", source_sha).decode().strip()
    epoch = git("show", "-s", "--format=%ct", source_sha).decode().strip()
    timestamp = datetime.fromtimestamp(
        int(epoch), tz=timezone.utc
    ).strftime("%Y-%m-%dT%H:%M:%SZ")
    build_identity = sha256(
        (
            "repository=c0h1b4/pacotinho-blog\n"
            f"commit={source_sha}\n"
            f"tree={tree_sha}\n"
            "platform=linux/amd64\n"
        ).encode()
    )
    dockerfile_digest = sha256(git("show", f"{source_sha}:Dockerfile"))
    lockfile_digest = sha256(git("show", f"{source_sha}:pnpm-lock.yaml"))

    with tempfile.TemporaryDirectory() as directory_name:
        directory = Path(directory_name)
        helper_path = directory / "sealed-context.py"
        helper_path.write_text(helper, encoding="utf-8")
        observed_digest_path = directory / "observed-digest"
        fake_docker = directory / "docker"
        fake_docker.write_text(
            "#!/usr/bin/python3\n"
            "from pathlib import Path\n"
            "import hashlib\n"
            "import os\n"
            "import sys\n"
            "payload = sys.stdin.buffer.read()\n"
            "if not payload:\n"
            "    raise SystemExit(1)\n"
            "Path(os.environ['FAKE_DOCKER_DIGEST']).write_text(\n"
            "    'sha256:' + hashlib.sha256(payload).hexdigest(), encoding='utf-8'\n"
            ")\n",
            encoding="utf-8",
        )
        fake_docker.chmod(0o755)

        helper_arguments = [
            "/usr/bin/python3",
            "-I",
            str(helper_path),
            "--source-sha",
            source_sha,
            "--tree-sha",
            tree_sha,
            "--source-committed-at",
            timestamp,
            "--source-date-epoch",
            epoch,
            "--build-identity",
            build_identity,
            "--dockerfile-sha256",
            dockerfile_digest,
            "--lockfile-sha256",
            lockfile_digest,
            "--image-repository",
            "ghcr.io/c0h1b4/pacotinho-blog",
            "--sbom-generator",
            SBOM_GENERATOR,
            "--",
        ]
        environment = os.environ.copy()
        environment["PATH"] = f"{directory}:{environment['PATH']}"
        environment["FAKE_DOCKER_DIGEST"] = str(observed_digest_path)

        valid = subprocess.run(
            helper_arguments
            + build_command(source_sha, tree_sha, timestamp, epoch, build_identity),
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
        )
        if valid.returncode != 0:
            raise RuntimeError(f"sealed helper rejected valid build: {valid.stderr}")
        context_digest = valid.stdout.strip()
        if not DIGEST_PATTERN.fullmatch(context_digest):
            raise RuntimeError(f"invalid context digest: {context_digest!r}")
        if observed_digest_path.read_text(encoding="utf-8") != context_digest:
            raise RuntimeError("Buildx input did not match the sealed context digest")

        observed_digest_path.unlink()
        replay = subprocess.run(
            helper_arguments
            + build_command(source_sha, tree_sha, timestamp, epoch, build_identity),
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
        )
        if replay.returncode != 0:
            raise RuntimeError(f"sealed helper replay failed: {replay.stderr}")
        if replay.stdout.strip() != context_digest:
            raise RuntimeError("sealed context digest changed on same-source replay")
        if observed_digest_path.read_text(encoding="utf-8") != context_digest:
            raise RuntimeError("replayed Buildx input did not match the context digest")

        observed_digest_path.unlink()
        unexpected_option = build_command(
            source_sha, tree_sha, timestamp, epoch, build_identity
        )
        unexpected_option[-1:-1] = ["--no-cache"]
        rejected_argument = subprocess.run(
            helper_arguments + unexpected_option,
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
        )
        if rejected_argument.returncode == 0:
            raise RuntimeError("sealed helper accepted an unreviewed build option")
        if observed_digest_path.exists():
            raise RuntimeError("rejected build option reached the Docker process")

        wrong_digest_arguments = helper_arguments.copy()
        digest_position = wrong_digest_arguments.index("--dockerfile-sha256") + 1
        wrong_digest_arguments[digest_position] = "sha256:" + ("f" * 64)
        rejected_source = subprocess.run(
            wrong_digest_arguments
            + build_command(source_sha, tree_sha, timestamp, epoch, build_identity),
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
        )
        if rejected_source.returncode == 0:
            raise RuntimeError("sealed helper accepted the wrong Dockerfile digest")
        if observed_digest_path.exists():
            raise RuntimeError("mismatched source identity reached the Docker process")

        wrong_scanner_arguments = helper_arguments.copy()
        scanner_position = wrong_scanner_arguments.index("--sbom-generator") + 1
        wrong_scanner_arguments[scanner_position] = (
            "docker/buildkit-syft-scanner@sha256:" + ("e" * 64)
        )
        rejected_scanner = subprocess.run(
            wrong_scanner_arguments
            + build_command(source_sha, tree_sha, timestamp, epoch, build_identity),
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
        )
        if rejected_scanner.returncode == 0:
            raise RuntimeError("sealed helper accepted an unreviewed SBOM generator")
        if observed_digest_path.exists():
            raise RuntimeError("unreviewed SBOM generator reached the Docker process")

    print("sealed_context_helper_tests_passed=true")


if __name__ == "__main__":
    main()
