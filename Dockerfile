FROM ros:humble-ros-base-jammy AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Global env
ENV CUDA_VERSION=12.3
ENV CUDNN_VERSION=8.9.5.29-1+cuda12.2
ENV TENSORRT_VERSION=8.6.1.6-1+cuda12.0
ENV OS=ubuntu2204

# Install essential libs/tools
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
  git \
  ssh \
  wget \
  cmake \
  curl \
  gosu \
  gnupg \
  vim \
  unzip \
  lsb-release \
  software-properties-common \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

# Install cuda toolkit and perform post-installation actions
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/${OS}/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && cuda_version_dashed=$(echo ${CUDA_VERSION} | sed -e "s/[.]/-/g") \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    cuda-command-line-tools-${cuda_version_dashed} \
    cuda-minimal-build-${cuda_version_dashed} \
    libcusparse-dev-${cuda_version_dashed} \
    libcublas-dev-${cuda_version_dashed} \
    libcurand-dev-${cuda_version_dashed} \
    cuda-nvml-dev-${cuda_version_dashed} \
    cuda-nvprof-${cuda_version_dashed} \
    && echo 'export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}' >> ~/.bashrc \
    && echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc \
    && mkdir -p /etc/vulkan/icd.d \
    && chmod 0755 /etc/vulkan/icd.d \
    && mkdir -p /etc/glvnd/egl_vendor.d \
    && chmod 0755 /etc/glvnd/egl_vendor.d \
    && mkdir -p /etc/OpenCL/vendors \
    && chmod 0755 /etc/OpenCL/vendors \
    && wget https://gitlab.com/nvidia/container-images/vulkan/raw/dc389b0445c788901fda1d85be96fd1cb9410164/nvidia_icd.json -O /etc/vulkan/icd.d/nvidia_icd.json \
    && chmod 0644 /etc/vulkan/icd.d/nvidia_icd.json \
    && wget https://gitlab.com/nvidia/container-images/opengl/raw/5191cf205d3e4bb1150091f9464499b076104354/glvnd/runtime/10_nvidia.json -O /etc/glvnd/egl_vendor.d/10_nvidia.json \
    && chmod 0644 /etc/glvnd/egl_vendor.d/10_nvidia.json \
    && touch /etc/OpenCL/vendors/nvidia.icd \
    && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd \
    && chmod 0644 /etc/OpenCL/vendors/nvidia.icd \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

# Install TensorRT
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    libcudnn8=${CUDNN_VERSION} \
    libnvinfer8=${TENSORRT_VERSION} \
    libnvinfer-plugin8=${TENSORRT_VERSION} \
    libnvparsers8=${TENSORRT_VERSION} \
    libnvonnxparsers8=${TENSORRT_VERSION} \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libcudnn8-dev=${CUDNN_VERSION} \
    libnvinfer-dev=${TENSORRT_VERSION} \
    libnvinfer-plugin-dev=${TENSORRT_VERSION} \
    libnvinfer-headers-dev=${TENSORRT_VERSION} \
    libnvinfer-headers-plugin-dev=${TENSORRT_VERSION} \
    libnvparsers-dev=${TENSORRT_VERSION} \
    libnvonnxparsers-dev=${TENSORRT_VERSION} \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

# Install more deps
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    geographiclib-tools \
    python3-vcstool \
    ccache \
    ros-"$ROS_DISTRO"-rmw-cyclonedds-cpp \
    && geographiclib-get-geoids egm2008-1 \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

# Install Kisak Mesa libs fix for RVIZ
RUN add-apt-repository -y ppa:kisak/kisak-mesa \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    libegl-mesa0 \
    libegl1-mesa-dev \
    libgbm-dev \
    libgbm1 \
    libgl1-mesa-dev \
    libgl1-mesa-dri \
    libglapi-mesa \
    libglx-mesa0 \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

# Setup ROS workspace folder
ENV ROS_WS /opt/ros_ws
WORKDIR $ROS_WS

# Set cyclone DDS ROS RMW
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

COPY ./cyclone_dds.xml $ROS_WS/

# Configure Cyclone cfg file
ENV CYCLONEDDS_URI=file://${ROS_WS}/cyclone_dds.xml

# Enable ROS log colorised output
ENV RCUTILS_COLORIZED_OUTPUT=1

# Copy repos urls list
COPY autoware_deps.repos ./
COPY autoware_tartan.repos ./

# Clone all repos and generate dependencies package list
RUN --mount=type=ssh mkdir src \
    && mkdir -p ~/.ssh \
    && ssh-keyscan github.com >> ~/.ssh/known_hosts \
    && vcs import src < autoware_deps.repos \
    && vcs import src < autoware_tartan.repos \
    && rosdep update && rosdep keys --ignore-src --from-paths src \
    | xargs rosdep resolve --rosdistro ${ROS_DISTRO} \
    | grep -v '^#' \
    | sed 's/ \+/\n/g'\
    | sort \
    > /rosdep-all-depend-packages.txt \
    && cat /rosdep-all-depend-packages.txt

# Install all the required depend packages from the generated list
RUN apt-get update \
    && cat /rosdep-all-depend-packages.txt | xargs apt-get install -y --no-install-recommends \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache


# -----------------------------------------------------------------------

FROM base AS prebuilt

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV CCACHE_DIR="/var/tmp/ccache"
ENV CC="/usr/lib/ccache/gcc"
ENV CXX="/usr/lib/ccache/g++"

# Import module repos lists
COPY ./modules_pkgs/autoware_common.txt "$ROS_WS"/
COPY ./modules_pkgs/autoware_perception.txt "$ROS_WS"/

# Set environment variables and persist them in /root/.bashrc
RUN export PERCEPTION_PKGS=$(tr '\n' ' ' < ./autoware_perception.txt) \
    && export COMMON_PKGS=$(tr '\n' ' ' < ./autoware_common.txt) \
    && echo "export PERCEPTION_PKGS='$PERCEPTION_PKGS'" >> /root/.bashrc \
    && echo "export COMMON_PKGS='$COMMON_PKGS'" >> /root/.bashrc

# # Source ROS setup for dependencies and build our code
# RUN . /opt/ros/"$ROS_DISTRO"/setup.sh \
#     && colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# -----------------------------------------------------------------------

FROM prebuilt AS dev

# Install basic dev tools (And clean apt cache afterwards)
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get -y --quiet --no-install-recommends install \
        # Command-line editor
        nano \
        # Ping network tools
        inetutils-ping \
        # Bash auto-completion for convenience
        bash-completion \
        # Python pip
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install WaymoOpenDataset
RUN pip install waymo-open-dataset-tf-2-12-0==1.6.4

# Add sourcing local workspace command to bashrc for convenience when running interactively
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> /root/.bashrc \
   && echo "source $ROS_WS/install/setup.bash" >> /root/.bashrc \
   && source /root/.bashrc \
    # Add colcon build alias for convenience
   && echo 'alias colcon_build="colcon build --symlink-install --cmake-args \
   -DCMAKE_BUILD_TYPE=Release && source install/setup.bash"' >> /root/.bashrc \
   && echo 'alias colcon_build_perception="colcon build --symlink-install --cmake-args \
   -DCMAKE_BUILD_TYPE=Release --packages-up-to $COMMON_PKGS $PERCEPTION_PKGS \
   && source install/setup.bash"' >> /root/.bashrc

# Enter bash for development
CMD ["bash"]

# -----------------------------------------------------------------------

FROM base AS runtime

# # Copy artifacts/binaries from prebuilt
# COPY --from=prebuilt $ROS_WS/install $ROS_WS/install

# # Add command to docker entrypoint to source newly compiled
# #   code when running docker container
# RUN sed --in-place --expression \
#         "\$isource \"$ROS_WS/install/setup.bash\" " \
#         /ros_entrypoint.sh

# Launch ros package
# CMD ["ros2", "launch", "av_camera_launch", "all_cams.launch.xml"]
CMD ["bash"]
