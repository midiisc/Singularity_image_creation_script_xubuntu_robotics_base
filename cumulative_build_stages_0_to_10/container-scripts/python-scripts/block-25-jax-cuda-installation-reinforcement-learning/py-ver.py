import re
ver = "${JAX_VER}"
match = re.match(r"(\\d+\.\\d+)", ver)
print(match.group(1) if match else '')
