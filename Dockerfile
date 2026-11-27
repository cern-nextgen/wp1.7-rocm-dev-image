FROM almalinux:9

ARG ROCM_VERSION=10.2
ARG AMDGPU_FAMILY=all

ENV ROCM_PATH=/opt/rocm
ENV PATH=${ROCM_PATH}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="ROCm SDK (AlmaLinux 9)" \
      org.opencontainers.image.version="${ROCM_VERSION}" \
      com.amd.rocm.install-method="packages"

# Layer 1: Cached across all GPU architectures
RUN dnf install -y dnf-plugins-core epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf install -y \
        ca-certificates \
        diffutils \
        environment-modules \
        git \
        gcc \
        gcc-c++ \
        make \
        binutils \
        glibc-devel \
        python3-devel \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        zlib-devel \
        expat-devel \
        xz && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/lib/dnf/history* /var/log/* /root/.cache

# Placed here so changing --build-arg AMDGPU_FAMILY only rebuilds Layer 2
ENV AMDGPU_FAMILY=${AMDGPU_FAMILY}
LABEL com.amd.rocm.gpu-coverage="${AMDGPU_FAMILY}"

# Layer 2: Rebuilds only when ROCM_VERSION or AMDGPU_FAMILY changes
RUN printf '%s\n' \
        '[amdrocm-stable]' \
        'name=AMD ROCm Core Stable Repository' \
        'baseurl=https://stable.repo.amd.com/rocm/core/packages/rhel9/x86_64' \
        'enabled=1' \
        'gpgcheck=1' \
        'gpgkey=https://stable.repo.amd.com/rocm/gpg/packages.gpg' \
        > /etc/yum.repos.d/amdrocm-stable.repo && \
    if [ -z "${AMDGPU_FAMILY}" ] || [ "${AMDGPU_FAMILY}" = "all" ]; then \
        ROCM_PKGS="amdrocm${ROCM_VERSION} amdrocm-core-sdk${ROCM_VERSION}"; \
    else \
        ROCM_PKGS="amdrocm${ROCM_VERSION}-${AMDGPU_FAMILY} amdrocm-core-sdk${ROCM_VERSION}-${AMDGPU_FAMILY}"; \
    fi && \
    dnf install -y ${ROCM_PKGS} && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/lib/dnf/history* /var/log/* && \
    echo "/opt/rocm/lib" > /etc/ld.so.conf.d/rocm.conf && \
    echo "/opt/rocm/lib64" >> /etc/ld.so.conf.d/rocm.conf && \
    ldconfig

WORKDIR /workspace
CMD ["/bin/bash"]
