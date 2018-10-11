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

    public class RdfQueryService : IDisposable
    {

        private readonly string dumpFileFullPath;
        private readonly RdfQueryServiceOptions options;
        private readonly ILogger logger;
        private readonly SparqlQueryParser queryParser;

        //////////
        private readonly ReaderWriterLockSlim loadGraphTaskLock = new ReaderWriterLockSlim();
        private Task<LoadedGraph> loadGraphTask;
        private long lastGraphDumpCheckedTimestamp;
        private DateTime lastGraphLoadedFileWriteTime;
        private long lastGraphLoadedFileLength = -1;
        //////////

        // Every after this milliseconds, we will check on disk whether the graph dump has been changed.
        private long CheckFileInterval = 3600 * 1000;

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
        }

        private Task<LoadedGraph> EnsureGraphLoadedAsync()
        {
            loadGraphTaskLock.EnterReadLock();
            try
            {
                if (loadGraphTask != null)
                {
                    if (!loadGraphTask.IsCompleted) return loadGraphTask;
                    var tickCount = Environment.TickCount;
                    if (Math.Sign(tickCount) == Math.Sign(lastGraphDumpCheckedTimestamp) && tickCount - lastGraphDumpCheckedTimestamp <= CheckFileInterval)
                    {
                        return loadGraphTask;
                    }
                }
            }
            finally
            {
                loadGraphTaskLock.ExitReadLock();
            }
            loadGraphTaskLock.EnterUpgradeableReadLock();
            try
            {
                if (loadGraphTask == null || loadGraphTask.IsCompleted)
                {
                    // Check whether the file has been changed since last load.
                    // TODO handle the cases where the files are symlinks
                    var file = new FileInfo(dumpFileFullPath);
                    loadGraphTaskLock.EnterWriteLock();
                    try
                    {
                        if (file.LastWriteTimeUtc != lastGraphLoadedFileWriteTime || file.Length != lastGraphLoadedFileLength)
                        {
                            logger.LogInformation("Graph dump has been changed since last check.");
                            loadGraphTask = Task.Run(LoadGraph);
                            // Suppose the file hasn't been changed during we load it.
                            lastGraphLoadedFileWriteTime = file.LastWriteTimeUtc;
                            lastGraphLoadedFileLength = file.Length;
                        }
                        else
                        {
                            logger.LogInformation("Graph dump has not been changed since last check.");
                        }
                        lastGraphDumpCheckedTimestamp = Environment.TickCount;
                    }
                    finally
                    {
                        loadGraphTaskLock.ExitWriteLock();
                    }
                }
                return loadGraphTask;
            }
            finally
            {
                loadGraphTaskLock.ExitUpgradeableReadLock();
            }
        }

        private LoadedGraph LoadGraph()
        {
            var sw = Stopwatch.StartNew();
            try
            {
                // Long running task.
                var g = new Graph();
                FileLoader.Load(g, options.DumpFilePath);
                var ds = new InMemoryDataset(g);
                logger.LogInformation("Initialized graph with {Tuples} tuples. Elapsed time: {Elapsed}.",
                    g.Triples.Count, sw.Elapsed);
                return new LoadedGraph(new LeviathanQueryProcessor(ds), g, ds);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error during initialization. Elapsed time: {Elapsed}.", sw.Elapsed);
                throw;
            }
        }

        public async Task<SparqlQueryResult> ExecuteQueryAsync(string expr, CancellationToken ct)
        {
            if (expr == null) throw new ArgumentNullException(nameof(expr));
            ct.ThrowIfCancellationRequested();
            var loadedGraph = await EnsureGraphLoadedAsync();
            if (expr == null) throw new ArgumentNullException(nameof(expr));
            ct.ThrowIfCancellationRequested();
            var sw = Stopwatch.StartNew();
            using (logger.BeginScope("ExprHash={ExprHash}", expr.GetHashCode()))
            {
                try
                {
                    logger.LogInformation("Start execute query; ExprLength={ExprLength}.", expr.Length);
                    var queryStr = new SparqlParameterizedString(expr);
                    foreach (var prefix in loadedGraph.Graph.NamespaceMap.Prefixes)
                    {
                        if (!queryStr.Namespaces.HasNamespace(prefix))
                        {
                            queryStr.Namespaces.AddNamespace(prefix, loadedGraph.Graph.NamespaceMap.GetNamespaceUri(prefix));
                        }
                    }
                    var query = queryParser.ParseFromString(queryStr);
                    logger.LogDebug("Parsed query. Elapsed time: {Elapsed}.", sw.Elapsed);
                    query.Timeout = (int)options.QueryTimeout.TotalMilliseconds;
                    query.Limit = options.ResultLimit;
                    ct.ThrowIfCancellationRequested();

                    var weakResult = loadedGraph.QueryProcessor.ProcessQuery(query);
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

        /// <inheritdoc />
        public void Dispose()
        {
            loadGraphTaskLock.Dispose();
        }

        private class LoadedGraph
        {
            public readonly LeviathanQueryProcessor QueryProcessor;
            public readonly IGraph Graph;
            public readonly InMemoryDataset Dataset;

            public LoadedGraph(LeviathanQueryProcessor queryProcessor, IGraph graph, InMemoryDataset dataset)
            {
                QueryProcessor = queryProcessor;
                Graph = graph;
                Dataset = dataset;
            }
        }

    }
}

