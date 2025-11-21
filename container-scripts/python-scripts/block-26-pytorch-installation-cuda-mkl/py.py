import torch
import os
import io
from contextlib import redirect_stdout

buf = io.StringIO()
with redirect_stdout(buf):
    torch.__config__.show()
config_output = buf.getvalue()
print(config_output, end="")

cuda_version = torch.version.cuda or "unknown"
print(f"CUDA build version: {cuda_version}")
expected_cuda = os.environ.get("EXPECTED_TORCH_CUDA_VERSION", "").strip()
if expected_cuda and cuda_version != "unknown" and not str(cuda_version).startswith(expected_cuda):
    raise SystemExit(f"Unexpected CUDA toolkit version reported by PyTorch (expected {expected_cuda}, got {cuda_version})")

if not torch.backends.mkl.is_available() and "MKL" not in config_output:
    raise SystemExit("Intel MKL backend not detected in PyTorch build")

if hasattr(torch.backends, "mkldnn"):
    print(f"MKLDNN available: {torch.backends.mkldnn.is_available()}")

cpu_matmul = torch.mm(torch.randn(128, 128), torch.randn(128, 128)).sum().item()
print(f"CPU matmul checksum: {cpu_matmul}")

print(f"PyTorch version: {torch.__version__}")
print(f"torch.cuda.is_available(): {torch.cuda.is_available()}")
