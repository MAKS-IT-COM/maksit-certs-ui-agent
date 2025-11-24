using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using MaksIT.CertsUI.Models.Requests;
using MaksIT.CertsUI.Agent.AuthorizationFilters;


namespace MaksIT.CertsUI.Agent.Controllers;

[ApiController]
[Route("[controller]")]
[ServiceFilter(typeof(ApiKeyAuthorizationFilter))]
public class CertsController : ControllerBase {

  private readonly Configuration _appSettings;
  private readonly ILogger<CertsController> _logger;

  public CertsController(
     IOptions<Configuration> appSettings,
     ILogger<CertsController> logger
  ) {
    _logger = logger;
    _appSettings = appSettings.Value;
  }

  [HttpPost("[action]")]
  public IActionResult Upload([FromBody] CertsUploadRequest requestData) {
    _logger.LogInformation("Uploading certificates");

    foreach (var (fileName, fileContent) in requestData.Certs) {
      System.IO.File.WriteAllText(Path.Combine(_appSettings.CertsPath, fileName), fileContent);
    }

    return Ok("Certificates uploaded successfully");
  }
}
