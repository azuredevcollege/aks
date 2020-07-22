FROM golang:alpine AS build

RUN apk update && apk add make && apk add git
RUN apk add -U --no-cache ca-certificates

# Create appuser.
ENV USER=appuser
ENV UID=10001 

RUN adduser \    
    --disabled-password \    
    --gecos "" \    
    --home "/nonexistent" \    
    --shell "/sbin/nologin" \    
    --no-create-home \    
    --uid "${UID}" \    
    "${USER}"

WORKDIR /
# current directory must be project root api-go
COPY . ./

RUN mkdir -p /dist/linux_amd64/release
RUN make build
#RUN mv ./dist/linux_amd64/release/api ./

FROM scratch AS runtime

WORKDIR /

# Import the user and group files from the builder.
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group
COPY --from=build /dist/linux_amd64/release /

USER appuser:appuser

ENTRYPOINT []