using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using VDS.RDF;
using VDS.RDF.Parsing;
using VDS.RDF.Query;
using VDS.RDF.Query.Datasets;

namespace GrayWing.Querying
{

    public class RdfQueryServiceOptions
    {

        /// <summary>
        /// Path to the RDF dump file.
        /// </summary>
        public string DumpFilePath { get; set; }

        public TimeSpan QueryTimeout { get; set; } = TimeSpan.FromSeconds(120);

        public int ResultLimit { get; set; } = 5000;

    }

    public class RdfQueryService
    {

        private readonly string dumpFileFullPath;
        private readonly RdfQueryServiceOptions options;
        private IGraph graph;
        private ISparqlDataset dataset;
        private readonly Task initializationTask;
        private readonly ILogger logger;
        private readonly SparqlQueryParser queryParser;
        private LeviathanQueryProcessor queryProcessor;

        public RdfQueryService(IOptions<RdfQueryServiceOptions> options, ILoggerFactory loggerFactory, IHostingEnvironment hosting)
        {
            this.options = options.Value;
            // Sanity check
            if (string.IsNullOrWhiteSpace(this.options.DumpFilePath))
                throw new ArgumentException("options.DumpFilePath should not be null or whitespace.", nameof(options));
            dumpFileFullPath = Path.Combine(hosting.ContentRootPath, this.options.DumpFilePath);
            if (!File.Exists(dumpFileFullPath))
                throw new FileNotFoundException("The specified file does not exist: " + this.options.DumpFilePath + ".", this.options.DumpFilePath);
            //
            logger = loggerFactory.CreateLogger<RdfQueryService>();
            queryParser = new SparqlQueryParser(SparqlQuerySyntax.Sparql_1_1);
            // Initialization should finish here.
            initializationTask = Task.Run(Initialize);
        }

        private void Initialize()
        {
            var sw = Stopwatch.StartNew();
            try
            {
                // Long running task.
                var g = new Graph();
                FileLoader.Load(g, options.DumpFilePath);
                var ds = new InMemoryDataset(g);
                graph = g;
                dataset = ds;
                queryProcessor = new LeviathanQueryProcessor(ds);
                logger.LogInformation("Initialized graph with {Tuples} tuples. Elapsed time: {Elapsed}.",
                    g.Triples.Count, sw.Elapsed);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error during initialization. Elapsed time: {Elapsed}.", sw.Elapsed);
                throw;
            }
        }

        public Task<SparqlQueryResult> ExecuteQueryAsync(string expr, CancellationToken ct)
        {
            if (expr == null) throw new ArgumentNullException(nameof(expr));
            if (ct.IsCancellationRequested) return Task.FromCanceled<SparqlQueryResult>(ct);
            if (initializationTask.IsCompletedSuccessfully)
                return Task.Factory.StartNew(() => ExecuteQuery(expr, ct), ct, TaskCreationOptions.LongRunning, TaskScheduler.Current);
            // Running / Error / Cancelled
            return ExecuteQueryAsyncCore();

            async Task<SparqlQueryResult> ExecuteQueryAsyncCore()
            {
                await initializationTask;
                return await Task.Factory.StartNew(() => ExecuteQuery(expr, ct), ct, TaskCreationOptions.LongRunning, TaskScheduler.Current);
            }
        }

        public SparqlQueryResult ExecuteQuery(string expr, CancellationToken ct)
        {
            if (expr == null) throw new ArgumentNullException(nameof(expr));
            ct.ThrowIfCancellationRequested();
            var sw = Stopwatch.StartNew();
            using (logger.BeginScope("ExprHash={ExprHash}", expr.GetHashCode()))
            {
                try
                {
                    logger.LogInformation("Start execute query; ExprLength={ExprLength}.", expr.Length);
                    var queryStr = new SparqlParameterizedString(expr) {Namespaces = graph.NamespaceMap};
                    var query = queryParser.ParseFromString(queryStr);
                    logger.LogDebug("Parsed query. Elapsed time: {Elapsed}.", sw.Elapsed);
                    query.Timeout = (int) options.QueryTimeout.TotalMilliseconds;
                    query.Limit = options.ResultLimit;
                    ct.ThrowIfCancellationRequested();

                    var weakResult = queryProcessor.ProcessQuery(query);
                    // returns either a SparqlResultSet or an IGraph instance
                    if (weakResult is IGraph)
                    {
                        logger.LogWarning("Query result is IGraph.");
                    }
                    var result = new SparqlQueryResult(weakResult);
                    logger.LogInformation("Executed query with {Results} {ResultType} results. Elapsed time: {Elapsed}.",
                        result.RecordsCount, result.ResultType, sw.Elapsed);
                    return result;
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Error during executing query. Elapsed time: {Elapsed}.", sw.Elapsed);
                    throw;
                }
            }
        }
    }
}
