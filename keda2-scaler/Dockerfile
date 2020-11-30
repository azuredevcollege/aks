FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
WORKDIR /app
COPY . ./
RUN dotnet build -o /app/out -c Release ./kedaqueue.csproj
FROM mcr.microsoft.com/dotnet/runtime:3.1 AS runtime
WORKDIR /app
COPY --from=build /app/out .
ENTRYPOINT ["dotnet", "kedaqueue.dll"]