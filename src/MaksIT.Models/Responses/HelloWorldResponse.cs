using MaksIT.Core.Abstractions.Webapi;


namespace MaksIT.CertsUI.Models.Responses;

public class HelloWorldResponse : ResponseModelBase {
  public string Message { get; set; }
}