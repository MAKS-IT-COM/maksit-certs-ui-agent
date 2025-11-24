namespace MaksIT.CertsUI.Agent;

public class Configuration {

  private string? _apiKey;
  public string ApiKey {
    get {
      var env = Environment.GetEnvironmentVariable("MAKS-IT_AGENT_API_KEY");
      return env ?? _apiKey ?? string.Empty;
    }

    set {
      _apiKey = value;
    }

  }

  private string? _certsPath;
  public string CertsPath {
    get {
      var env = Environment.GetEnvironmentVariable("MAKS-IT_AGENT_CERTS_PATH");
      return env ?? _certsPath ?? string.Empty;
    }

    set {
      _certsPath = value;
    }
  }
}
