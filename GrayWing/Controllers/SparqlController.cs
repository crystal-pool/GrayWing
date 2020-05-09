using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using GrayWing.Querying;
using Microsoft.ApplicationInsights;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace GrayWing.Controllers
{
    [Route("sparql")]
    [ApiController]
    public class SparqlController : ControllerBase
    {

        private readonly RdfQueryService queryService;
        private readonly TelemetryClient telemetryClient;
        private ILogger logger;
        private const int QueryExpressionBufferSize = 4096;
        private const int QueryExpressionMaximumLength = 16 * 1024;

        public SparqlController(RdfQueryService queryService, ILoggerFactory loggerFactory, TelemetryClient telemetryClient)
        {
            this.queryService = queryService;
            this.telemetryClient = telemetryClient;
            this.logger = loggerFactory.CreateLogger<SparqlController>();
        }

        // GET sparql?query=
        [HttpGet]
        public async Task Get(string query)
        {
            if (string.IsNullOrWhiteSpace(query)) return;
            var result = await queryService.ExecuteQueryAsync(query, HttpContext.RequestAborted);
            QueryResultSerializationHelper.SendToClient(HttpContext, result);
        }

        // POST sparql
        [HttpPost]
        public async Task<IActionResult> Post()
        {
            var sb = new StringBuilder();
            var buffer = new Memory<char>(new char[QueryExpressionBufferSize]);
            using (var reader = new StreamReader(Request.Body, Encoding.UTF8))
            {
                while (true)
                {
                    var count = await reader.ReadAsync(buffer, HttpContext.RequestAborted);
                    sb.Append(buffer.Slice(0, count).Span);
                    if (count < QueryExpressionBufferSize) break;
                    if (sb.Length > QueryExpressionMaximumLength)
                    {
                        return StatusCode(StatusCodes.Status413PayloadTooLarge, "The request query string is too long.");
                    }
                }
            }

            var query = sb.ToString();
            if (string.IsNullOrWhiteSpace(query))
                return StatusCode(StatusCodes.Status400BadRequest, "Missing query string.");
            var sw = new Stopwatch();
            var stageName = "Query";
            var metrics = new Dictionary<string, double>();
            try
            {
                sw.Start();
                var result = await queryService.ExecuteQueryAsync(query, HttpContext.RequestAborted);
                metrics["QueryMs"] = sw.ElapsedMilliseconds;
                stageName = "SendToClient";
                sw.Restart();
                QueryResultSerializationHelper.SendToClient(HttpContext, result);
                metrics["SendToClientMs"] = sw.ElapsedMilliseconds;
                telemetryClient.TrackEvent("QueryEnd", new Dictionary<string, string> {{"Query", query}}, metrics);
                return new EmptyResult();
            }
            catch (Exception ex)
            {
                // TODO we should distinguish between syntax error & query execution failure.
                telemetryClient.TrackException(ex,
                    new Dictionary<string, string>
                    {
                        {"Query", query},
                        {"Stage", stageName},
                        {"StageMs", sw.ElapsedMilliseconds.ToString()}
                    }, metrics);
                return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
            }
        }

    }
}
