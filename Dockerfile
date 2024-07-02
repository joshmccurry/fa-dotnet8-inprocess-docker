FROM mcr.microsoft.com/dotnet/sdk:8.0 AS installer-env

#Build Function App
RUN cd ~
COPY . /src/dotnet-function-app
RUN cd /src/dotnet-function-app && \
    mkdir -p /home/site/wwwroot && \
    dotnet publish *.csproj --output /home/site/wwwroot

#Build Function Host
RUN cd ~
RUN git clone https://github.com/Azure/azure-functions-host.git
RUN cd /azure-functions-host && \
    mkdir -p /azure-functions-host && \
    dotnet publish src/WebJobs.Script.WebHost/WebJobs.Script.WebHost.csproj --output /azure-functions-host

#Set Base Image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
ENV ASPNETCORE_URLS=http://+:80 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true \
    FUNCTIONS_INPROC_NET8_ENABLED=1 \
    FUNCTIONS_WORKER_RUNTIME=dotnet

#Copy Host to base Image
COPY --from=installer-env ["/azure-functions-host", "/azure-functions-host"]
#Copy App to base Image
COPY --from=installer-env ["/home/site/wwwroot", "/home/site/wwwroot"]

#Start the function host
CMD dotnet /azure-functions-host/Microsoft.Azure.WebJobs.Script.WebHost.dll