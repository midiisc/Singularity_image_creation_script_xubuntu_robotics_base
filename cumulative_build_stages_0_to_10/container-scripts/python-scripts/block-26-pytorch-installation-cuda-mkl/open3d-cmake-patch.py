#!/usr/bin/env python3
"""
Purpose: python scripts block 26 pytorch installation cuda mkl open3d cmake patch.py
"""
import re
import sys

file_path = "3rdparty/find_dependencies.cmake"
try:
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern 1: Match find_library(CPP_LIBRARY c++ PATHS ${CLANG_LIBDIR} REQUIRED NO_DEFAULT_PATH)
    # This is the REQUIRED call that causes FATAL_ERROR if not found
    # Search order: prefer LLVM-14 (stable), then 15, 16, 17, 18, 11
    pattern1 = r'find_library\s*\(\s*CPP_LIBRARY\s+c\+\+\s+PATHS\s+\$\{CLANG_LIBDIR\}\s+REQUIRED\s+NO_DEFAULT_PATH\s*\)'
    replacement1 = 'find_library(CPP_LIBRARY NAMES c++ c++abi stdc++ PATHS ${CLANG_LIBDIR} /usr/lib/llvm-14/lib /usr/lib/llvm-15/lib /usr/lib/llvm-16/lib /usr/lib/llvm-17/lib /usr/lib/llvm-18/lib /usr/lib/llvm-11/lib /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib REQUIRED NO_DEFAULT_PATH)'
    content = re.sub(pattern1, replacement1, content)
    
    # Pattern 2: Match find_library(CPPABI_LIBRARY c++abi PATHS ${CLANG_LIBDIR} REQUIRED NO_DEFAULT_PATH)
    pattern2 = r'find_library\s*\(\s*CPPABI_LIBRARY\s+c\+\+abi\s+PATHS\s+\$\{CLANG_LIBDIR\}\s+REQUIRED\s+NO_DEFAULT_PATH\s*\)'
    replacement2 = 'find_library(CPPABI_LIBRARY NAMES c++abi c++ PATHS ${CLANG_LIBDIR} /usr/lib/llvm-14/lib /usr/lib/llvm-15/lib /usr/lib/llvm-16/lib /usr/lib/llvm-17/lib /usr/lib/llvm-18/lib /usr/lib/llvm-11/lib /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib REQUIRED NO_DEFAULT_PATH)'
    content = re.sub(pattern2, replacement2, content)
    
    # Pattern 3: Match find_library(CPP_LIBRARY c++ PATHS ${llvm_lib_dir} NO_DEFAULT_PATH) in loop
    # This is the search loop that tries versions 7-19
    pattern3 = r'find_library\s*\(\s*CPP_LIBRARY\s+c\+\+\s+PATHS\s+\$\{llvm_lib_dir\}\s+NO_DEFAULT_PATH\s*\)'
    replacement3 = 'find_library(CPP_LIBRARY NAMES c++ c++abi stdc++ PATHS ${llvm_lib_dir} /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib NO_DEFAULT_PATH)'
    content = re.sub(pattern3, replacement3, content)
    
    # Pattern 4: Match find_library(CPPABI_LIBRARY c++abi PATHS ${llvm_lib_dir} NO_DEFAULT_PATH) in loop
    pattern4 = r'find_library\s*\(\s*CPPABI_LIBRARY\s+c\+\+abi\s+PATHS\s+\$\{llvm_lib_dir\}\s+NO_DEFAULT_PATH\s*\)'
    replacement4 = 'find_library(CPPABI_LIBRARY NAMES c++abi c++ PATHS ${llvm_lib_dir} /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib NO_DEFAULT_PATH)'
    content = re.sub(pattern4, replacement4, content)
    
    if content != original_content:
        with open(file_path, 'w') as f:
            f.write(content)
        print("✓ C++ library detection patched successfully")
        print(f"  Made {len(re.findall(r'find_library.*CPP', original_content)) - len(re.findall(r'find_library.*CPP', content))} replacements")
        sys.exit(0)
    else:
        print("⚠ CPP_LIBRARY patterns not found in expected format, trying sed fallback")
        sys.exit(1)
except Exception as e:
    print(f"⚠ Error patching C++ library detection: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(2)
