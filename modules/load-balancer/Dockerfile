# Build stage
FROM rust:1.88 AS builder
RUN apt-get update && apt-get install -y cmake
WORKDIR /app
# Copy manifests and resolve dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src && touch src/main.rs  # Create a dummy source file to satisfy Cargo
RUN cargo fetch
COPY . .
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/target/release/pingora_balancer /app/
CMD ["/app/pingora_balancer"]