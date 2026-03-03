# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN cat go.mod && go mod download

COPY . .
# Run tidy to sync go.mod with code
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o bridge .

# Final stage
FROM gcr.io/distroless/static-debian11

WORKDIR /
COPY --from=builder /app/bridge /bridge

USER nonroot:nonroot
ENTRYPOINT ["/bridge"]
