var builder = WebApplication.CreateBuilder(args);
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

var app = builder.Build();

app.MapGet("/", () => "Hello from distroless buildpack builder!");

app.MapGet("/health", () => Results.Json(new { status = "OK" }));

app.Run();
