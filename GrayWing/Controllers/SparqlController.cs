using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using GrayWing.Querying;
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
        private ILogger logger;
        private const int QueryExpressionBufferSize = 4096;
        private const int QueryExpressionMaximumLength = 16 * 1024;

        public SparqlController(RdfQueryService queryService, ILoggerFactory loggerFactory)
        {
            this.queryService = queryService;
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
        public async Task Post()
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
                        var content = new StringContent("The request query is too large.");
                        Response.StatusCode = StatusCodes.Status413PayloadTooLarge;
                        await content.CopyToAsync(Response.Body);
                        return;
                    }
                }
            }
            var query = sb.ToString();
            if (string.IsNullOrWhiteSpace(query)) return;
            var result = await queryService.ExecuteQueryAsync(query, HttpContext.RequestAborted);
            QueryResultSerializationHelper.SendToClient(HttpContext, result);
        }

    }
}
