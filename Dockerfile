# ===========
# Build stage
# ===========
FROM golang:1.25-alpine AS builder

# Install build dependencies and Node.js
RUN apk add --no-cache ca-certificates curl gcc musl-dev nodejs npm tzdata upx wget

# Install templ CLI
RUN go install github.com/a-h/templ/cmd/templ@latest

WORKDIR /app

# Copy go mod files and download Go deps
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY . .

# (Tailwind v4) Install Tailwind core + CLI into the builder image
# This creates node_modules in /app, used only in this stage
RUN npm install --save-dev tailwindcss@latest @tailwindcss/cli@latest

# Generate templ files
RUN templ generate

# Build CSS with Tailwind v4 CLI
# Ensure public/input.css uses:  @import "tailwindcss";
RUN npx @tailwindcss/cli@latest -i ./public/input.css -o ./public/style.css --minify

# Build the Go application
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-w -s" -o watchma ./cmd/main.go

RUN upx --best --lzma watchma

# ============
# Runtime stage
# ============
FROM alpine:latest

RUN apk add --no-cache ca-certificates musl

WORKDIR /app

# Copy binary and assets from the builder
COPY --from=builder /app/watchma .
COPY --from=builder /app/public ./public

EXPOSE 58008

CMD ["./watchma"]

