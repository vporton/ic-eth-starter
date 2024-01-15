import Types "../lib/Types";
import V "../lib/Verifier";

actor Main {
    shared func scoreBySignedEthereumAddress(address: V.EthereumAddress, signature: Text): async Float {
        await* V.scoreBySignedEthereumAddress(
            address,
            signature,
            scorerId,
            scoreHTTPTransform,
        );
    };

    shared query func scoreHTTPTransform(args: Types.TransformArgs): async Types.HttpResponsePayload {
        V.scoreHTTPTransform(args);
    };
}