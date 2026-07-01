#!/bin/sh

set -eu

FRAGMENT="$1"
if [ ! -f .config ]; then
    echo "apply-config: .config missing — run 'make allnoconfig' first" >&2
    exit 1
fi
if [ ! -f "$FRAGMENT" ]; then
    echo "apply-config: fragment not found: $FRAGMENT" >&2
    exit 1
fi

sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$FRAGMENT" | \
while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    if [ -z "$key" ] || [ "$key" = "$line" ]; then
        echo "apply-config: malformed line: $line" >&2
        exit 1
    fi

    case "$value" in
        y|m)
            if grep -qE "^# ${key} is not set\$" .config; then
                sed -i "s|^# ${key} is not set\$|${key}=${value}|" .config
            elif grep -qE "^${key}=" .config; then
                sed -i "s|^${key}=.*\$|${key}=${value}|" .config
            else
                echo "${key}=${value}" >> .config
            fi
            ;;
        n)
            if grep -qE "^${key}=" .config; then
                sed -i "s|^${key}=.*\$|# ${key} is not set|" .config
            elif ! grep -qE "^# ${key} is not set\$" .config; then
                echo "# ${key} is not set" >> .config
            fi
            ;;
        *)
            if grep -qE "^${key}=" .config; then
                sed -i "s|^${key}=.*\$|${key}=${value}|" .config
            elif grep -qE "^# ${key} is not set\$" .config; then
                sed -i "s|^# ${key} is not set\$|${key}=${value}|" .config
            else
                echo "${key}=${value}" >> .config
            fi
            ;;
    esac
done

yes "" | make oldconfig >/dev/null

grep -qE '^CONFIG_CAT=y' .config || { echo "apply-config: CONFIG_CAT not set after merge"; exit 1; }
grep -qE '^CONFIG_AWK=y' .config || { echo "apply-config: CONFIG_AWK not set after merge"; exit 1; }
grep -qE '^CONFIG_TAR=y' .config || { echo "apply-config: CONFIG_TAR not set after merge"; exit 1; }

yes "" | make oldconfig 2>&1 | grep -E 'nonexistent symbol' && {
    echo "apply-config: fragment references nonexistent Kconfig symbols (above)"
    exit 1
} || true

echo "apply-config: merged $(grep -cE '^CONFIG_[A-Z]+_?[A-Z0-9_]*=y' .config) options"
