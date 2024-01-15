import Types "../lib/Types";
import V "../lib/Verifier";
import Conf "../../Config";

actor Main {
    public shared func scoreBySignedEthereumAddress(address: V.EthereumAddress, signature: Text): async Float {
        // A real app would store the verified address somewhere instead of just returning the score to frontend.
        await* V.scoreBySignedEthereumAddress(
            address,
            signature,
            Conf.scorerId,
            scoreHTTPTransform,
        );
    };

    public shared query func scoreHTTPTransform(args: Types.TransformArgs): async Types.HttpResponsePayload {
        V.scoreHTTPTransform(args);
    };
}