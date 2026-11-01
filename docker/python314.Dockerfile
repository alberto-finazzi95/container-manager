# Use Python 3.14 on slim Debian Bookworm to provide the required runtime
# without adding non-essential packages to the base image.
FROM python:3.14-slim-bookworm

# Avoid creating .pyc files, which are unnecessary in an ephemeral container,
# and send output to the logs immediately instead of buffering it.
# Disable pip's cache as well, since it would take up image space without
# being reused between container runs.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Set the working directory for subsequent commands and application startup;
# relative paths will be resolved from /app.
WORKDIR /app

# Create a dedicated group and user with stable UID/GID values, no home
# directory, and no login shell, then assign /app to them. This lets the
# application use its working directory without running as root.
RUN groupadd --gid 10001 app && \
    useradd --uid 10001 --gid 10001 --no-create-home --home-dir /app --shell /usr/sbin/nologin app && \
    chown 10001:10001 /app

# Allow the requirements file path to be set at build time, for example when
# the file comes from another repository or a different location in the build
# context. The default is requirements.txt.
ARG REQUIREMENTS_FILE=requirements.txt
# Copy the file into the image under the name expected by pip and assign
# ownership to the application user to keep file permissions consistent.
COPY --chown=10001:10001 ${REQUIREMENTS_FILE} ./requirements.txt

# Install Sonar Scanner CLI and remove downloaded archives and apt metadata
# to keep the image smaller.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl unzip && \
    curl --proto "=https" --fail --location --silent --show-error \
        --output sonar-scanner.zip \
        https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.2.1.4610-linux-x64.zip && \
    unzip sonar-scanner.zip -d /opt && \
    mv /opt/sonar-scanner-* /opt/sonar-scanner && \
    ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner && \
    rm sonar-scanner.zip && \
    rm -rf /var/lib/apt/lists/*

# Install binary distributions (wheels) only, avoiding source builds and
# execution of their build scripts. --require-hashes requires approved hashes
# for every requirement and dependency to verify the downloaded packages.
RUN python -m pip install --only-binary :all: --require-hashes --requirement requirements.txt\
    && python -m pip install --only-binary :all: coverage==7.16.2 ruff==0.12.0 black==25.1.0

# Run all subsequent container processes as the unprivileged application
# user instead of root.
USER app:app

# Add /app to Python's module search path so the application and modules in
# the working directory can be imported.
ENV PYTHONPATH=/app
