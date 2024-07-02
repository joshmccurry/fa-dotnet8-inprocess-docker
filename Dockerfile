ARG HOST_VERSION=4.1034.2

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS installer-env
ARG HOST_VERSION
#Build Function App
RUN cd ~
COPY . /src/dotnet-function-app
RUN cd /src/dotnet-function-app && \
    mkdir -p /home/site/wwwroot && \
    dotnet publish *.csproj --output /home/site/wwwroot

#Build Function Host
RUN cd ~
RUN git clone --branch v${HOST_VERSION} https://github.com/Azure/azure-functions-host.git
RUN cd /azure-functions-host && \
    mkdir -p /azure-functions-host && \
    dotnet publish src/WebJobs.Script.WebHost/WebJobs.Script.WebHost.csproj --output /azure-functions-host --runtime linux-x64

# Lifted from https://github.com/Azure/azure-functions-docker/blob/dev/host/4/bullseye/amd64/dotnet/dotnet-inproc/dotnet.Dockerfile

#Get Scripts
RUN cd ~
RUN git clone https://github.com/Azure/azure-functions-docker.git
RUN cd /azure-functions-docker/host/4/bullseye/amd64/dotnet/dotnet-inproc && \
    mkdir -p /scripts && \
    cp -R . /scripts

#Get ExtensionBundles
RUN cd ~
RUN apt-get update && \
    apt-get install -y gnupg wget unzip && \
    EXTENSION_BUNDLE_VERSION_V4=4.17.0 && \
    EXTENSION_BUNDLE_FILENAME_V4=Microsoft.Azure.Functions.ExtensionBundle.${EXTENSION_BUNDLE_VERSION_V4}_linux-x64.zip && \
    wget https://functionscdn.azureedge.net/public/ExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V4/$EXTENSION_BUNDLE_FILENAME_V4 && \
    mkdir -p /FuncExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V4 && \
    unzip /$EXTENSION_BUNDLE_FILENAME_V4 -d /FuncExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V4 && \
    rm -f /$EXTENSION_BUNDLE_FILENAME_V4 &&\
    find /FuncExtensionBundles/ -type f -exec chmod 644 {} \;

#Set Base Image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime-image
ARG HOST_VERSION
ENV ASPNETCORE_URLS=http://+:80 \
    HOME=/home \
    FUNCTIONS_WORKER_RUNTIME=dotnet \
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    HOST_VERSION=${HOST_VERSION} \
    ASPNETCORE_CONTENTROOT=/azure-functions-host\
    DOTNET_RUNNING_IN_CONTAINER=true \
    AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true \
    FUNCTIONS_INPROC_NET8_ENABLED=1 \
    FUNCTIONS_WORKER_RUNTIME=dotnet

RUN apt-get update && \
    apt-get install -y libc-dev

#Copy Host to base Image
COPY --from=installer-env ["/FuncExtensionBundles", "/FuncExtensionBundles"]
COPY --from=installer-env ["/azure-functions-host", "/azure-functions-host"]
COPY --from=installer-env ["/scripts", "."]
#Copy App to base Image
COPY --from=installer-env ["/home/site/wwwroot", "/home/site/wwwroot"]

#Copy the cert script
RUN mkdir /opt/startup
RUN cp install_ca_certificates.sh /opt/startup/install_ca_certificates.sh
RUN cp start_nonappservice.sh /opt/startup/start_nonappservice.sh
RUN chmod +x /opt/startup/install_ca_certificates.sh && chmod +x /opt/startup/start_nonappservice.sh

#Start the function host
#CMD dotnet /azure-functions-host/Microsoft.Azure.WebJobs.Script.WebHost.dll
CMD ./opt/startup/start_nonappservice.sh