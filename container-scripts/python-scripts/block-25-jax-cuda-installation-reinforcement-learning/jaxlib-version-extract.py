import os
import re
ver = os.environ.get("JAXLIB_VER", "")
match = re.match(r"(\d+\.\d+)", ver)
print(match.group(1) if match else '')
