# autoware_launch

A forked version of the launch configuration repository for [Autoware](https://github.com/autowarefoundation/autoware), containing node configurations, their parameters and docker container to run autoware modules.

## Docker setup

Requirements:

- NVIDIA Drivers 545+
- NVIDIA Container [Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-apt)
- Autoware artifacts (Download [here](https://github.com/autowarefoundation/autoware/tree/main/ansible/roles/artifacts#autoware-artifacts))
  - Make sure `autoware_data` directory is downloaded in your `$HOME`

### Build Docker

Clone the repositories using the `vcs` command (`sudo apt install python3-vcstool`). Note: You need an SSH key configured for your GitHub account.

```bash
vcs import ./ < autoware_deps.repos
vcs import ./ < autoware_tartan.repos
```

Ensure you have at least 26 GB of free disk space. To build, run:

```bash
./build.sh
```

The process may take several minutes as CUDA Runtime and TensorRT libraries are installed inside the Docker image.

After building, an `av_autoware:latest-dev` Docker image should be available. Verify with:

```bash
docker image list | grep av_autoware

# av_autoware  latest-dev  f6639f41bbdf   4 hours ago   13.2GB
```

## Compile Autoware packages

Run the docker container:

```bash
./dev.sh
```

Once inside the container, run

```bash
colcon_build_perception
```

This cmd will ONLY build autoware perception related packages (~114 pkgs)

If you require to build the entire autoware workspace (~330+ pkgs) you can do:

```bash
colcon_build
```

After running the Docker container with `dev.sh`, the `install` and `build` directories will be automatically created in the root of the repository. All build artifacts will be stored there after building the Autoware packages. This way, you do not need to rebuild again every time you reopen a new Docker container.

## Run Perception (Detection only)

The Docker container is configured with Cyclone DDS as the ROS RMW with custom parameters. To ensure nodes run correctly with this configuration, you need to increase the maximum receive buffer size in your host machine.

```bash
# Create sysctl cfg file with the required setting
sudo sh -c 'echo "net.core.rmem_max=2147483647" > /etc/sysctl.d/10-cyclone-max.conf'

# Reload sysctl settings
sudo sysctl --system
```

If you haven't already, run the container using `dev.sh`. After that, follow these steps:

```bash
# Source the ROS workspace
source /opt/ros_ws/install/setup.bash

# If launching for the first time, optimize/build TensorRT engine models

## Build the Lidar CenterPoint model
ros2 launch lidar_centerpoint lidar_centerpoint.launch.xml model_name:=centerpoint build_only:=true

##  Build the YOLOX model for image object detection
ros2 launch tensorrt_yolox yolox_s_plus_opt.launch.xml build_only:=true

# Launch Autoware perception
ros2 launch autoware_launch autoware.launch.xml
```
