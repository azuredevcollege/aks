FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build
WORKDIR /app
# copy csproj and restore as distinct layers
COPY *.sln .
COPY AspnetWebApplication/*.csproj ./AspnetWebApplication/
COPY AspnetWebApplication/*.config ./AspnetWebApplication/
RUN nuget restore

# copy everything else and build app
COPY AspnetWebApplication/. ./AspnetWebApplication/
WORKDIR /app/AspNetWebApplication
RUN msbuild /p:Configuration=Release


FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS runtime
WORKDIR /inetpub/wwwroot
COPY --from=build /app/AspnetWebApplication/. ./