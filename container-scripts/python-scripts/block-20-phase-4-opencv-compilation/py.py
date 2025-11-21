import apt
import sys
pkg_name = "libopencv-dev"
try:
    cache = apt.Cache()
except Exception:
    sys.exit(1)
if pkg_name not in cache:
    sys.exit(0)
pkg = cache[pkg_name]
candidate = pkg.candidate
if candidate is None:
    sys.exit(0)
priority = getattr(candidate, 'policy_priority', None)
if priority is None:
    sys.exit(1)
if priority <= 0:
    sys.exit(0)
sys.exit(1)
