import os
import re
jaxlib_ver = os.environ.get("JAXLIB_VER", "")
match = re.search(r"cuda(11|12)", jaxlib_ver)
print(match.group(0) if match else '')
