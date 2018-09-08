using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace GrayWing.Telemetry
{
    public static class TrackingIdGenerator
    {

        public static readonly byte MagicByte = 73;
        public static readonly int IdBytesLength = 15;
        public static readonly int IdStringLength = IdBytesLength * 8 / 6;      // 20

        private static readonly Random rnd = new Random();

        private static uint EvaluateHash(byte[] seq)
        {
            var hash = 2166136261U;
            for (int i = 0; i < 11; i++) hash = unchecked((hash ^ seq[i]) * 16777619U);
            return hash;
        }

        public static string GenerateId(byte typeByte)
        {
            //  0       MagicByte ^ typeByte
            //  1~8     DateTime Ticks
            //  9~10    Random short
            //  11~14   Hash
            //  Length = 15
            var idBytes = new byte[IdBytesLength];
            idBytes[0] = (byte) (MagicByte ^ typeByte);
            BitConverter.TryWriteBytes(new Span<byte>(idBytes, 1, 8), DateTime.UtcNow.Ticks);
            rnd.NextBytes(new Span<byte>(idBytes, 10, 2));
            BitConverter.TryWriteBytes(new Span<byte>(idBytes, 11, 4), EvaluateHash(idBytes));
            return Convert.ToBase64String(idBytes);
        }

        public static bool ValidateId(string id, byte typeByte)
        {
            if (id == null) throw new ArgumentNullException(nameof(id));
            if (id.Length != IdStringLength) return false;
            var idBytes = new byte[IdBytesLength];
            if (!Convert.TryFromBase64String(id, idBytes, out var written) || written != IdBytesLength)
                return false;
            if (idBytes[0] != (byte)(MagicByte ^ typeByte)) return false;
            var hash = EvaluateHash(idBytes);
            if (hash != BitConverter.ToUInt32(new ReadOnlySpan<byte>(idBytes, 11, 4))) return false;
            return true;
        }

    }
}
