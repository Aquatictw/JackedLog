#!/bin/bash

# Create screenshots directory if it doesn't exist
mkdir -p screenshots

echo "Screenshot tool ready!"
echo "Press 's' to capture a screenshot"
echo "Press 'q' to quit"
echo ""

# Find the next screenshot number
get_next_number() {
    local max=0
    shopt -s nullglob
    for file in screenshots/screenshot_*.png; do
        if [[ -f "$file" ]]; then
            num=$(basename "$file" | sed 's/screenshot_\([0-9]*\)\.png/\1/')
            if [[ $num =~ ^[0-9]+$ ]] && ((num > max)); then
                max=$num
            fi
        fi
    done
    shopt -u nullglob
    printf "%03d" $((max + 1))
}

# Main loop
while true; do
    # Read single character without waiting for Enter
    read -rsn1 key

    case "$key" in
        s|S)
            num=$(get_next_number)
            filename="screenshots/screenshot_${num}.png"
            temp_file="/tmp/screenshot_temp.png"

            echo -n "Capturing screenshot... "
            if adb exec-out screencap -p > "$temp_file" 2>/dev/null; then
                echo -n "cropping... "
                if convert "$temp_file" -gravity North -chop 0x75 "$filename" 2>/dev/null; then
                    rm "$temp_file"
                    echo "✓ Saved: $filename"
                else
                    # Fallback if ImageMagick is not installed
                    mv "$temp_file" "$filename"
                    echo "✓ Saved: $filename (ImageMagick not found, skipped cropping)"
                fi
            else
                echo "✗ Failed! Is your device connected?"
                echo "  Try: adb devices"
            fi
            ;;
        q|Q)
            echo "Exiting..."
            exit 0
            ;;
    esac
done
