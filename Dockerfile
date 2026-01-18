# Multi-stage Docker build for JARVIX v2.0 - Scalable deployment
# Phase 6: Horizontal Scaling Support

# ============= RUST BUILD STAGE =============
FROM rust:1.92-slim as rust-builder

WORKDIR /build

# Copy Rust workspace
COPY engine/Cargo.toml engine/Cargo.toml
COPY engine/src engine/src

# Build release binary
RUN apt-get update && \
    apt-get install -y pkg-config libssl-dev && \
    cd engine && \
    cargo build --release && \
    strip target/release/jarvix

# ============= JULIA STAGE =============
FROM julia:1.12-slim as julia-env

WORKDIR /app

# Pre-install Julia packages
RUN julia -e 'using Pkg; Pkg.add(["JSON", "Statistics", "Distributed"])'

# ============= NODE BUILD STAGE =============
FROM node:20-slim as node-builder

WORKDIR /app

# Copy package files
COPY app/package*.json ./

# Install dependencies including Puppeteer
RUN apt-get update && \
    apt-get install -y \
    chromium \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils && \
    npm ci --only=production && \
    rm -rf /var/lib/apt/lists/*

# ============= FINAL RUNTIME STAGE =============
FROM ubuntu:24.04

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    ca-certificates \
    chromium-browser \
    fonts-liberation \
    libatomic1 \
    && rm -rf /var/lib/apt/lists/*

# Copy Julia from julia-env stage
COPY --from=julia-env /usr/local/julia /usr/local/julia
ENV PATH="/usr/local/julia/bin:${PATH}"

# Copy Node.js from node-builder stage
COPY --from=node-builder /usr/local/bin/node /usr/local/bin/node
COPY --from=node-builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# Copy Rust binary
COPY --from=rust-builder /build/engine/target/release/jarvix /usr/local/bin/jarvix

# Copy application files
COPY science/ /app/science/
COPY app/ /app/app/
COPY --from=node-builder /app/node_modules /app/app/node_modules

# Create data directories
RUN mkdir -p /app/data/{raw,clean,invalid,scores,top,reports}

# Set Puppeteer to use system Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD jarvix --version || exit 1

# Default command
CMD ["jarvix", "--help"]

# Metadata
LABEL maintainer="JARVIX Team"
LABEL version="2.0.0"
LABEL description="JARVIX v2.0 - Scalable OSINT & Scoring Engine"
LABEL phase="6-scalability"
