using MaksIT.CertsUI.Agent;
using MaksIT.CertsUI.Agent.AuthorizationFilters;

var builder = WebApplication.CreateBuilder(args);

// Extract configuration
var configuration = builder.Configuration;

// Configure strongly typed settings objects
var configurationSection = configuration.GetSection("Configuration");
var appSettings = configurationSection.Get<Configuration>() ?? throw new ArgumentNullException();

// Allow configurations to be available through IOptions<Configuration>
builder.Services.Configure<Configuration>(configurationSection);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddScoped<ApiKeyAuthorizationFilter>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment()) {
  app.UseSwagger();
  app.UseSwaggerUI();
}

app.UseAuthorization();

app.MapControllers();

app.Run();
