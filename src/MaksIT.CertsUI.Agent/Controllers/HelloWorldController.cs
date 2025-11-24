using Microsoft.AspNetCore.Mvc;
using MaksIT.CertsUI.Agent.AuthorizationFilters;


namespace MaksIT.CertsUI.Agent.Controllers;

[ApiController]
[Route("[controller]")]
[ServiceFilter(typeof(ApiKeyAuthorizationFilter))]
public class HelloWorldController : ControllerBase {

  [HttpGet]
  public IActionResult Get() {
    return Ok("Hello, World!");
  }
}
