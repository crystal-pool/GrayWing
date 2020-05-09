using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using GrayWing.Querying;
using GrayWing.Telemetry;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace GrayWing
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            var aiStorageFolder = Configuration.GetValue<string>("ApplicationInsightsStorageFolder", null);
            if (aiStorageFolder != null)
            {
                // For Linux OS
                services.AddSingleton<ITelemetryChannel>(new ServerTelemetryChannel {StorageFolder = aiStorageFolder});
            }
            services.AddSingleton<ITelemetryInitializer, MyTelemetryInitializer>();
            services.AddApplicationInsightsTelemetry(Configuration);

            services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Latest);
            services.Configure<RdfQueryServiceOptions>(Configuration.GetSection("RdfQueryService"));
            services.AddSingleton<RdfQueryService>();

            // For sparqlWriter.Save to work.
            services.Configure<KestrelServerOptions>(options =>
            {
                options.AllowSynchronousIO = true;
            });
            services.Configure<IISServerOptions>(options =>
            {
                options.AllowSynchronousIO = true;
            });
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            var usesReverseProxy = Configuration.GetValue("UseReverseProxy", false);
            if (usesReverseProxy)
            {
                app.UseForwardedHeaders(new ForwardedHeadersOptions
                {
                    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
                });
            }

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseHsts();
            }

            if (!usesReverseProxy)
            {
                app.UseHttpsRedirection();
            }

            app.UseStaticFiles();
            app.UseRouting();
            app.UseCookiePolicy();
            app.UseEndpoints(endpoints => endpoints.MapControllers());

        }
    }
}
