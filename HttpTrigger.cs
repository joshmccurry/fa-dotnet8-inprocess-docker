using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace Azure.Test.Function
{
    public static class HttpTrigger
    {
        [FunctionName("HttpTrigger")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(
                AuthorizationLevel.Anonymous, "get", "post", Route = null)] 
                HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

                var version = new{
                    EnvironmentVersion = Environment.Version.ToString(),
                    SystemVersion = System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription
                };

            return new OkObjectResult(version);
        }
    }
}
