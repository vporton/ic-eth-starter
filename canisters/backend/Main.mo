import Types "../lib/Types";
import V "../lib/Verifier";
import Conf "../../Config";

actor Main {
    public shared func scoreBySignedEthereumAddress({address: Text; signature: Text}): async Float {
        // A real app would store the verified address somewhere instead of just returning the score to frontend.
        await* V.scoreBySignedEthereumAddress({
            address;
            signature;
            scorerId = Conf.scorerId;
            transform = removeHTTPHeaders;
        });
    };

    public shared query func removeHTTPHeaders(args: Types.TransformArgs): async Types.HttpResponsePayload {
        V.removeHTTPHeaders(args);
    };
}