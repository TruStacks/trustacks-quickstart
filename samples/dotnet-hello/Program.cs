// Minimal ASP.NET Core hello-world for the TruStacks workshop quickstart.
// The Code Reviewer agent fingerprints this repo as csharp / aspnetcore;
// the DevOps Engineer emits CI + Helm + ArgoCD against it on /plan.

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "hello from TruStacks quickstart");
app.MapGet("/healthz", () => "ok");

app.Run();
