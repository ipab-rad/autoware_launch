#!/bin/bash
# ----------------------------------------------------------------
# Run dev container and add local code for live development
# ----------------------------------------------------------------

# Default value for headless
headless=false

print_info() {
    echo "Usage: dev.sh [--headless] [--help | -h]"
    echo ""
    echo "Options:"
    echo "  --headless     Run the Docker image without X11 forwarding"
    echo "  --help, -h     Display this help message and exit."
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --headless) headless=true ;;
    --help | -h)
        print_info
        exit 0
        ;;
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
done

MOUNT_X=""
if [ "$headless" = "false" ]; then
    MOUNT_X="-e DISPLAY=$DISPLAY -v /tmp/.X11-unix/:/tmp/.X11-unix"
    xhost + >/dev/null
fi

mkdir -p install
mkdir -p build

# shellcheck disable=SC2086
# Run docker image with local code volumes for development
docker run -it --rm --net host --privileged \
    --gpus all \
    ${MOUNT_X} \
    -e XAUTHORITY="${XAUTHORITY}" \
    -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /dev:/dev \
    -v /tmp:/tmp \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$HOME"/autoware_data:/root/autoware_data \
    -v ./cyclone_dds.xml:/opt/ros_ws/cyclone_dds.xml \
    -v ./autoware_launch:/opt/ros_ws/src/autoware_launch \
    -v ./autoware.universe:/opt/ros_ws/src/autoware.universe \
    -v ./deps:/opt/ros_ws/src/deps \
    -v ./install:/opt/ros_ws/install \
    -v ./build:/opt/ros_ws/build \
    av_autoware:latest-dev
