using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.AspNetCore.Http;
using Microsoft.Net.Http.Headers;

namespace GrayWing.Telemetry
{
    /// <summary>
    /// Provides extra information for AI telemetry.
    /// </summary>
    public class MyTelemetryInitializer : ITelemetryInitializer
    {

        public const string UserIdCookieName = "SessionId1";
        public const string SessionIdCookieName = "SessionId2";
        public const byte UserIdTypeByte = 20;
        public const byte SessionIdTypeByte = 24;
        
        private readonly IHttpContextAccessor httpContextAccessor;

        public MyTelemetryInitializer(IHttpContextAccessor httpContextAccessor)
        {
            this.httpContextAccessor = httpContextAccessor ?? throw new ArgumentNullException(nameof(httpContextAccessor));
        }

        /// <inheritdoc />
        public void Initialize(ITelemetry telemetry)
        {
            var context = httpContextAccessor.HttpContext;
            if (context == null) return;
            var tracking = context.Features.Get<TelemetryTrackingFeature>();
            if (tracking == null)
            {
                tracking = TelemetryTrackingFeature.FromHttpContext(context);
                context.Features.Set(tracking);
            }
            telemetry.Context.User.Id = tracking.UserId;
            telemetry.Context.Session.Id = tracking.SessionId;
            telemetry.Context.User.UserAgent = context.Request.Headers[HeaderNames.UserAgent];
        }

        private sealed class TelemetryTrackingFeature
        {

            public readonly string UserId;

            public readonly string SessionId;

            public static TelemetryTrackingFeature FromHttpContext(HttpContext context)
            {
                Debug.Assert(context != null);
                var userId = context.Request.Cookies[UserIdCookieName];
                var sessionId = context.Request.Cookies[SessionIdCookieName];
                if (userId == null || !TrackingIdGenerator.ValidateId(userId, UserIdTypeByte))
                {
                    Debug.Assert(!context.Response.HasStarted);
                    userId = TrackingIdGenerator.GenerateId(UserIdTypeByte);
                    context.Response.Cookies.Append(UserIdCookieName, userId, new CookieOptions { Expires = DateTimeOffset.UtcNow.AddYears(1) });
                }
                if (sessionId == null || !TrackingIdGenerator.ValidateId(sessionId, SessionIdTypeByte))
                {
                    Debug.Assert(!context.Response.HasStarted);
                    sessionId = TrackingIdGenerator.GenerateId(SessionIdTypeByte);
                    context.Response.Cookies.Append(SessionIdCookieName, sessionId);
                }
                return new TelemetryTrackingFeature(userId, sessionId);
            }

            public TelemetryTrackingFeature(string userId, string sessionId)
            {
                UserId = userId;
                SessionId = sessionId;
            }
        }

    }
}
