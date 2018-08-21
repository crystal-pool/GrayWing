using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Net.Http.Headers;
using VDS.RDF;
using VDS.RDF.Query;
using VDS.RDF.Query.Datasets;
using VDS.RDF.Writing;

namespace GrayWing.Querying
{
    public static class QueryResultSerializationHelper
    {

        // See https://github.com/dotnetrdf/dotnetrdf/blob/5b7fc480346c90eb9b164fb4f8ee09f378442d52/Libraries/dotNetRDF.Web/HandlerHelper.cs#L157
        /// <summary>
        /// Helper function which returns the Results (Graph/Triple Store/SPARQL Results) back to the Client in one of their accepted formats
        /// </summary>
        /// <param name="context">Context of the HTTP Request</param>
        /// <param name="result">Results of the Sparql Query</param>
        /// <param name="config">Handler Configuration</param>
        public static void SendToClient(HttpContext context, SparqlQueryResult result)
        {
            MimeTypeDefinition definition = null;
            const string TEXT_PLAIN = "text/plain";
            var acceptTypes = context.Request.Headers[HeaderNames.Accept];

            // Return the Results
            if (result.SparqlResultSet != null)
            {
                ISparqlResultsWriter sparqlWriter = null;

                // Try and get a MIME Type Definition using the HTTP Requests Accept Header
                if (acceptTypes.Count > 0)
                {
                    definition = MimeTypesHelper.GetDefinitions((IEnumerable<string>) acceptTypes).FirstOrDefault(d => d.CanWriteSparqlResults);
                }
                // Try and get the registered Definition for SPARQL Results XML
                if (definition == null)
                {
                    definition = MimeTypesHelper.GetDefinitions(MimeTypesHelper.SparqlResultsXml[0]).FirstOrDefault();
                }
                // If Definition is still null create a temporary definition
                if (definition == null)
                {
                    definition = new MimeTypeDefinition("SPARQL Results XML", MimeTypesHelper.SparqlResultsXml, Enumerable.Empty<String>());
                    definition.SparqlResultsWriterType = typeof(VDS.RDF.Writing.SparqlXmlWriter);
                }

                // Set up the Writer appropriately
                sparqlWriter = definition.GetSparqlResultsWriter();
                context.Response.ContentType = definition.CanonicalMimeType;
                // HandlerHelper.ApplyWriterOptions(sparqlWriter, config);

                // Send Result Set to Client
                context.Response.Headers[HeaderNames.ContentEncoding] = definition.Encoding.WebName;
                sparqlWriter.Save(result.SparqlResultSet, new StreamWriter(context.Response.Body, definition.Encoding));
            }
            else if (result.Graph != null)
            {
                IRdfWriter rdfWriter = null;
                var ctype = TEXT_PLAIN;
                // Try and get a MIME Type Definition using the HTTP Requests Accept Header
                if (acceptTypes.Count > 0)
                {
                    definition = MimeTypesHelper.GetDefinitions((IEnumerable<string>) acceptTypes).FirstOrDefault(d => d.CanWriteRdf);
                }
                if (definition == null)
                {
                    // If no appropriate definition then use the GetWriter method instead
                    rdfWriter = MimeTypesHelper.GetWriter((IEnumerable<string>) acceptTypes, out ctype);
                }
                else
                {
                    rdfWriter = definition.GetRdfWriter();
                }

                // Setup the writer
                if (definition != null) ctype = definition.CanonicalMimeType;
                context.Response.ContentType = ctype;
                //HandlerHelper.ApplyWriterOptions(rdfWriter, config);

                // Clear any existing Response
                //context.Response.Clear();

                // Send Graph to Client
                if (definition != null)
                {
                    context.Response.Headers[HeaderNames.ContentEncoding] = definition.Encoding.WebName;
                    rdfWriter.Save(result.Graph, new StreamWriter(context.Response.Body, definition.Encoding));
                }
                else
                {
                    rdfWriter.Save(result.Graph, new StreamWriter(context.Response.Body));
                }
            }
            else
            {
                Debug.Assert(result == SparqlQueryResult.Null);
            }
        }

    }
}
