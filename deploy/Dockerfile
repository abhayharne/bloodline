# Build from the repository root: docker build -f deploy/Dockerfile .
FROM golang:1.22-bookworm AS build
WORKDIR /src
COPY api/go.mod api/go.sum ./
RUN go mod download
COPY api/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /bloodline ./cmd/server
RUN mkdir -p /data

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /bloodline /bloodline
COPY --from=build --chown=65532:65532 /data /data
WORKDIR /data
ENV PORT=8080 DB_PATH=/data/bloodline.db
EXPOSE 8080
ENTRYPOINT ["/bloodline"]
