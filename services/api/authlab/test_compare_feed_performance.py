import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class PerformanceGateTests(unittest.TestCase):
    def check_gate(self, mutation, expected):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for round_number in range(1, 4):
                for mode in ("legacy", "batch"):
                    value = 10.0 if mode == "legacy" else 5.0
                    data = {"Source": "1d829b2623a6c32830ee1b74fae6c99a436ad3b3" if mode == "legacy" else "candidate",
                            "Complete": True, "Warmup": 10, "Samples": 80, "Rounds": 1, "Threshold": .40,
                            "Cohorts": [{"round": round_number, "Mode": mode, "Kind": kind, "Samples": [value]*80, "P95": value, "Errors": []}
                                        for kind in ("home20", "next20", "home10", "next5")]}
                    if mode == "batch" and round_number == 3:
                        mutation(data)
                    (root / f"{mode}-{round_number}.json").write_text(json.dumps(data))
            result = subprocess.run([sys.executable, str(Path(__file__).with_name("compare-feed-performance.py")), directory], capture_output=True)
            report = json.loads((root / "comparison.json").read_text())
            self.assertEqual(result.returncode, 0 if expected else 1, result.stderr)
            self.assertEqual(report["PASS"], expected)

    def test_every_cohort_must_pass(self):
        self.check_gate(lambda _: None, True)
        def fail_one(data):
            data["Cohorts"][-1].update(Samples=[7.0]*80, P95=7.0)
        self.check_gate(fail_one, False)

    def test_rejects_incomplete_or_invalid_samples(self):
        self.check_gate(lambda data: data.update(Complete=False), False)
        self.check_gate(lambda data: data["Cohorts"][-1].update(P95=1.0), False)
        self.check_gate(lambda data: data["Cohorts"][-1].update(Samples=[float("nan")]*80), False)


if __name__ == "__main__":
    unittest.main()
