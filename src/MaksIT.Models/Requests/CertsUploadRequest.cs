using MaksIT.Core.Abstractions.Webapi;


namespace MaksIT.CertsUI.Models.Requests;

public class CertsUploadRequest : RequestModelBase {
  public Dictionary<string, string> Certs { get; set; }
}
