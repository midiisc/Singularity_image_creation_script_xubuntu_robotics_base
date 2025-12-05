#!/usr/bin/env python3
"""
Purpose: python scripts block 26 legacy pytorch source build openblas pytorch installation verification.py
"""
import sys
import torch

print(f"  PyTorch version: {torch.__version__}")
print(f"  Python version: {sys.version}")

# Check CUDA availability
if torch.cuda.is_available():
    print(f"  ✓ CUDA available: {torch.version.cuda}")
    print(f"  ✓ GPU device: {torch.cuda.get_device_name(0)}")
    print(f"  ✓ CUDA compute capability: {torch.cuda.get_device_capability(0)}")
else:
    print("  ⚠ CUDA not available (CPU-only build)")

# Test basic tensor operations
try:
    x = torch.randn(3, 3)
    y = torch.randn(3, 3)
    z = torch.mm(x, y)
    print("  ✓ Basic tensor operations working")
except Exception as e:
    print(f"  ⚠ Tensor operation error: {e}")

# Check MKL availability (should not be available, using OpenBLAS)
try:
    import torch.backends.mkl
    if torch.backends.mkl.is_available():
        print("  ⚠ MKL available (unexpected, should use OpenBLAS)")
    else:
        print("  ✓ MKL not available (using OpenBLAS as expected)")
except ImportError:
    print("  ✓ MKL not available (using OpenBLAS as expected)")

# Check BLAS backend
if hasattr(torch.backends, 'openblas'):
    print("  ✓ OpenBLAS backend available")

print("  ✓ PyTorch verification complete")
