using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;


namespace MaksIT.CertsUI.Agent.AuthorizationFilters;

public class ApiKeyAuthorizationFilter : IAuthorizationFilter {

  private readonly Configuration _appSettings;

  public ApiKeyAuthorizationFilter(
    IOptions<Configuration> appSettings
  ) {
    _appSettings = appSettings.Value;
  }

  public void OnAuthorization(AuthorizationFilterContext context) {
    if (!context.HttpContext.Request.Headers.TryGetValue("X-API-KEY", out var extractedApiKey)) {
      context.Result = new UnauthorizedResult();
      return;
    }

    if (!_appSettings.ApiKey.Equals(extractedApiKey)) {
      context.Result = new UnauthorizedResult();
      return;
    }
  }
}