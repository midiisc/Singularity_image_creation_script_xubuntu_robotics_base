import re
match = re.search(r"cuda(11|12)", "${JAXLIB_VER}")
print(match.group(0) if match else '')
