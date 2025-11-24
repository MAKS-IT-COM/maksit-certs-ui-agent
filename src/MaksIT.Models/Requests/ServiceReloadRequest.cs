using MaksIT.Core.Abstractions.Webapi;


namespace MaksIT.CertsUI.Models.Requests;

public class ServiceReloadRequest : RequestModelBase {
  public string ServiceName { get; set; }
}

