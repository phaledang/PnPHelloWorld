using System.Security.Cryptography.X509Certificates;
using Microsoft.Extensions.DependencyInjection;
using PnP.Core.Auth.Services.Builder.Configuration;
using PnP.Core.Services;
using PnP.Core.Services.Builder.Configuration;

internal class Program
{
    private static async Task Main(string[] args)
    {
        // use environment variables or other secure configuration management in production scenarios
        var tenantId = Environment.GetEnvironmentVariable("TENANT_ID");
        var clientId = Environment.GetEnvironmentVariable("CLIENT_ID");
        var siteUrl = Environment.GetEnvironmentVariable("SITE_URL");

        var cert = X509CertificateLoader.LoadPkcs12FromFile(
            @"C:\certs\pnpapp.pfx",
            "YourStrongPassword123!",
            X509KeyStorageFlags.MachineKeySet | X509KeyStorageFlags.Exportable);

        var services = new ServiceCollection();

        services.AddPnPCore(options =>
        {
            options.PnPContext.GraphFirst = true;
            options.Sites.Add("DefaultSite", new PnPCoreSiteOptions
            {
                SiteUrl = siteUrl
            });
        });

        services.AddPnPCoreAuthentication(options =>
        {
            options.Credentials.Configurations.Add("appcert",
                new PnPCoreAuthenticationCredentialConfigurationOptions
                {
                    ClientId = clientId,
                    TenantId = tenantId,
                    X509Certificate = new PnPCoreAuthenticationX509CertificateOptions
                    {
                        Certificate = cert
                    }
                });

            options.Credentials.DefaultConfiguration = "appcert";

            options.Sites.Add("DefaultSite", new PnPCoreAuthenticationSiteOptions
            {
                AuthenticationProviderName = "appcert"
            });
        });

        var provider = services.BuildServiceProvider();
        var factory = provider.GetRequiredService<IPnPContextFactory>();

        using var context = await factory.CreateAsync("DefaultSite");
        var web = await context.Web.GetAsync(p => p.Title);

        Console.WriteLine($"Site title: {web.Title}");
    }
}