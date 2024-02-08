import Config "src/lib/Verifier";

module {
    public let config: Config.Config = {
        // Please, create a scorer and API key at https://api.scorer.gitcoin.co
        scorerId = <NUMBER>;
        scorerAPIKey = "<KEY>";
        scorerUrl = "https://api.scorer.gitcoin.co";
    };
}