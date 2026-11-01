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

# Install binary distributions (wheels) only, avoiding source builds and
# execution of their build scripts. --require-hashes requires approved hashes
# for every requirement and dependency to verify the downloaded packages.
RUN python -m pip install --only-binary :all: --require-hashes --requirement requirements.txt

# Run all subsequent container processes as the unprivileged application
# user instead of root.
USER app:app

# Add /app to Python's module search path so the application and modules in
# the working directory can be imported.
ENV PYTHONPATH=/app
