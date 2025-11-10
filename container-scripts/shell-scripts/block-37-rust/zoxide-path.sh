#!/bin/sh
# Add /root/.local/bin to PATH for zoxide
if [ -d "/root/.local/bin" ]; then
    case ":${PATH}:" in
        *:/root/.local/bin:*)
            # Already present
            ;;
        *)
            export PATH="/root/.local/bin:${PATH}"
            ;;
    esac
fi
