using System;
using VDS.RDF;
using VDS.RDF.Query;

namespace GrayWing.Querying
{
    public struct SparqlQueryResult : IEquatable<SparqlQueryResult>
    {

        public static readonly SparqlQueryResult Null = new SparqlQueryResult(); 

        private readonly object result;

        public SparqlQueryResult(object result)
        {
            if (result != null && !(result is SparqlResultSet || result is IGraph))
                throw new ArgumentException("result should be either SparqlResultSet or IGraph.", nameof(result));
            this.result = result;
        }

        public SparqlResultSet SparqlResultSet => result as SparqlResultSet;

        public IGraph Graph => result as IGraph;

        public int RecordsCount
        {
            get
            {
                if (result is SparqlResultSet srs) return srs.Count;
                if (result is IGraph g) return g.Triples.Count;
                return 0;
            }
        }

        public Type ResultType => result?.GetType();
        
        /// <inheritdoc />
        public bool Equals(SparqlQueryResult other)
        {
            return result == other.result;
        }

        /// <inheritdoc />
        public override bool Equals(object obj)
        {
            if (ReferenceEquals(null, obj)) return false;
            return obj is SparqlQueryResult && Equals((SparqlQueryResult) obj);
        }

        /// <inheritdoc />
        public override int GetHashCode()
        {
            return (result != null ? result.GetHashCode() : 0);
        }

        public static bool operator ==(SparqlQueryResult left, SparqlQueryResult right)
        {
            return left.Equals(right);
        }

        public static bool operator !=(SparqlQueryResult left, SparqlQueryResult right)
        {
            return !left.Equals(right);
        }
    }
}
