FROM oven/bun:1.2.10 AS builder

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .

RUN bunx prisma generate
RUN bun run build

FROM oven/bun:1.2.10-slim

# install zsh and build dependencies for node-pty
RUN apt-get update && apt-get install -y \
    zsh \
    curl \
    python3 \
    make \
    g++ \
    build-essential \
    git \
    && apt-get clean

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs openssl && \
    npm install -g npm@latest && \
    npm install -g pnpm vite typescript ts-node && \
    apt-get clean

# copy .zshrc
COPY .zshrc /root/.zshrc

WORKDIR /app

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/preview.ts ./preview.ts

# Copy and build pty-wrapper
COPY pty-wrapper /app/pty-wrapper
RUN cd /app/pty-wrapper && npm install && npm run build

RUN bun install --production --frozen-lockfile
# Set default environment variables
ENV PORT=3000 \
    WORKDIR_NAME=/home/project \
    COEP=credentialless \
    FORWARD_PREVIEW_ERRORS=true \
    NODE_ENV=development

# Cache dependencies for all templates
RUN git clone --filter=blob:none --sparse https://github.com/planetarium/agent8-templates ./agent8-templates && \
    cd agent8-templates && \
    git sparse-checkout init --no-cone && \
    git sparse-checkout set */package.json

WORKDIR /app/agent8-templates
COPY pnpm-workspace.yaml ./pnpm-workspace.yaml

ENV PNPM_HOME=/pnpm-temp \
    PNPM_STORE_DIR=/pnpm-temp/store

# Create directories for the pnpm cache
RUN mkdir -p /pnpm-temp/store /pnpm/store

# This will be overridden at container startup with a script to copy from read-only volume
RUN pnpm install --prod


ENV PNPM_HOME=/pnpm \
    PNPM_STORE_DIR=/pnpm/store

# Copy the init script for pnpm store and grant execute permission
COPY init-pnpm-store.sh /app/init-pnpm-store.sh
RUN chmod +x /app/init-pnpm-store.sh

WORKDIR /home/project

EXPOSE 3000

# Use the init script as entrypoint that will setup pnpm store and then run the original entrypoint
ENTRYPOINT ["/app/init-pnpm-store.sh", "bun", "/app/dist/index.js"]
