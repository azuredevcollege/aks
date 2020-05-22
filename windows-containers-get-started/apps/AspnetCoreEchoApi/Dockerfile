# Setup environment
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build

## Setup build space
WORKDIR /app
COPY . ./

## 
#### This is a great place to set up environment information
#### such as versioning, build time etc.
##

## Build app
RUN dotnet publish -o /app/out -c Release -r win-x64 --self-contained false ./AspnetCoreEchoApi.csproj

# Build runtime image
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-nanoserver-1809 AS runtime

## Copy build
WORKDIR /app
COPY --from=build /app/out .

# Select non-root port
ENV ASPNETCORE_URLS=http://+:5000

# Launch dll
ENTRYPOINT ["dotnet", "AspnetCoreEchoApi.dll"]