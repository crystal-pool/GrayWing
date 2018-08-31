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
            try
            {
                var result = await queryService.ExecuteQueryAsync(query, HttpContext.RequestAborted);
                QueryResultSerializationHelper.SendToClient(HttpContext, result);
                return new EmptyResult();
            }
            catch (Exception ex)
            {
                // TODO we should distinguish between syntax error & query execution failure.
                return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
            }
        }

    }
}
