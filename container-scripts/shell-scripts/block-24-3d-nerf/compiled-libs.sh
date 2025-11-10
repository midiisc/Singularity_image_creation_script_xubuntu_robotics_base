# Priority paths for compiled libraries
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:\${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="/usr/local:\${CMAKE_PREFIX_PATH:-}"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:\${PKG_CONFIG_PATH:-}"
