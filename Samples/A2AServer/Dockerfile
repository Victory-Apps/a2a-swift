# Build stage
FROM swift:6.0-noble AS build

WORKDIR /app

# Copy Package.swift first for dependency caching
COPY Package.swift .

# Resolve dependencies (cached layer unless Package.swift changes)
RUN swift package resolve

# Copy source code
COPY Sources/ Sources/

# Build the server in release mode
RUN swift build -c release --static-swift-stdlib

# Runtime stage
FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/.build/release/A2AServer /usr/local/bin/
COPY products.json .

EXPOSE 8080

ENTRYPOINT ["A2AServer"]
