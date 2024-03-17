import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Char "mo:base/Char";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Types "./Types";
import JSON "mo:json.mo/JSON";
import Date "mo:date.mo/Date";

module {
    public type EthereumAddress = Blob;

    public type Config = {
        scorerId: Nat;
        scorerAPIKey: Text; // "<KEY>"
        scorerUrl: Text; // "https://api.scorer.gitcoin.co"
    };

    let ic : Types.IC = actor ("aaaaa-aa"); // management canister

    func obtainSuccessfulResponse(request: Types.HttpRequestArgs): async* Text {
        Cycles.add<system>(20_000_000);
        let response: Types.HttpResponsePayload = await ic.http_request(request);
        if (response.status != 200) {
            Debug.trap("Passport HTTP response code " # Nat.toText(response.status))
        };
        let ?body = Text.decodeUtf8(Blob.fromArray(response.body)) else {
            Debug.trap("Passport response is not UTF-8");
        };
        body;
    };

    public func obtainSuccessfulJSONResponse(request: Types.HttpRequestArgs): async* JSON.JSON {
        let body = await* obtainSuccessfulResponse(request);
        let ?json = JSON.parse(body) else {
            Debug.trap("Passport response is not JSON");
        };
        json;
    };

    public type IC_ETH = actor {
       verify_ecdsa: query(eth_address: Text, message: Text, Signature: Text) -> async Bool;
    };

    public func checkAddressOwner({ic_eth: IC_ETH; address: Text; signature: Text; nonce: Text}): async* () {
        // the same text as returned by `GET /registry/signing-message`
        let message = "I hereby agree to submit my address in order to score my associated Gitcoin Passport from Ceramic.\n\nNonce: "
            # nonce # "\n";
        if (not(await ic_eth.verify_ecdsa(address, message, signature))) {
            Debug.trap("You are not the owner of the Ethereum account");
        };
    };

    public func scoreByEthereumAddress({
        address: Text;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
        config: Config;
    }): async* Text {
        let request : Types.HttpRequestArgs = {
            body = null;
            headers = [{name = "X-API-KEY"; value = config.scorerAPIKey}];
            max_response_bytes = ?10000;
            method = #get;
            url = config.scorerUrl # "/registry/score/" # Nat.toText(config.scorerId) # "/" # address;
            transform = ?{
                function = transform;
                context = Blob.fromArray([]);
            };
        };
        await* obtainSuccessfulResponse(request);
    };

    public func scoreBySignedEthereumAddress({
        ic_eth: IC_ETH;
        address: Text;
        signature: Text;
        nonce: Text;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
        config: Config;
    }): async* Text {
        await* checkAddressOwner({ic_eth; address; signature; nonce});
        await* scoreByEthereumAddress({address; transform; config});
    };

    public func submitEthereumAddressForScore({
        address: Text;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
        config: Config;
    }): async* Text {
        let requestBody = JSON.show(
            #Object ([
                ("address", #String address),
                ("scorer_id", #String(Nat.toText(config.scorerId))),
                // ("signature", #String TODO),
                // ("nonce", #String TODO),
            ]),
        );
        let request : Types.HttpRequestArgs = {
            body = ?(Blob.toArray(Text.encodeUtf8(requestBody)));
            headers = [
                {name = "X-API-KEY"; value = config.scorerAPIKey},
                {name = "Content-Type"; value = "application/json"},
            ];
            max_response_bytes = ?10000;
            method = #post;
            url = config.scorerUrl # "/registry/submit-passport";
            transform = ?{
                function = transform;
                context = Blob.fromArray([]);
            };
        };
        await* obtainSuccessfulResponse(request);
    };

    public func getEthereumSigningMessage({
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
        config: Config;
    }): async* {message: Text; nonce: Text} {
        let request : Types.HttpRequestArgs = {
            body = null;
            headers = [
                {name = "X-API-KEY"; value = config.scorerAPIKey},
            ];
            max_response_bytes = ?10000;
            method = #get;
            url = config.scorerUrl # "/registry/signing-message";
            transform = ?{
                function = transform;
                context = Blob.fromArray([]);
            };
        };
        let response = await* obtainSuccessfulJSONResponse(request);
        let #Object obj = response else {
            Debug.trap("Wrong JSON format");
        };
        var message1: ?Text = null;
        var nonce1: ?Text = null;
        for (e in obj.vals()) {
            if (e.0 == "message") {
                let #String message0 = e.1 else {
                    Debug.trap("Wrong JSON format");
                };
                message1 := ?message0;
            } else if (e.0 == "nonce") {
                let #String nonce0 = e.1 else {
                    Debug.trap("Wrong JSON format");
                };
                nonce1 := ?nonce0;
            };
        };
        let (?message, ?nonce) = (message1, nonce1) else {
            Debug.trap("Wrong JSON format");
        };
        {message; nonce};
   };

    public func submitSignedEthereumAddressForScore({
        ic_eth: IC_ETH;
        address: Text;
        signature: Text;
        nonce: Text;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
        config: Config;
    }): async* Text {
        await* checkAddressOwner({ic_eth; address; signature; nonce});
        await* submitEthereumAddressForScore({address; transform; config});
    };

    public func extractItemScoreFromBody(body: Text): Float {
        let ?json = JSON.parse(body) else {
            Debug.trap("Passport response is not JSON");
        };
        extractItemScoreFromJSON(json);
    };

    public func extractItemScoreFromJSON(json: JSON.JSON): Float {
        let #Object obj = json else {
            Debug.trap("Wrong JSON format");
        };
        for (e in obj.vals()) {
            if (e.0 == "score") {
                let #String score = e.1 else {
                    Debug.trap("Wrong JSON format");
                };
                // Scorer returns `"0E-9"` if zero score:
                if (score == "0E-9") {
                    return 0.0;
                };
                return textToFloat(score);
            }
        };
        Debug.trap("No score");
    };

    public func extractDateFromBody(body: Text): Time.Time {
        let ?json = JSON.parse(body) else {
            Debug.trap("Passport response is not JSON");
        };
        extractDateFromJSON(json);
    };

    public func extractDateFromJSON(json: JSON.JSON): Time.Time {
        let #Object obj = json else {
            Debug.trap("Wrong JSON format");
        };
        for (e in obj.vals()) {
            if (e.0 == "last_score_timestamp") {
                let #String time = e.1 else {
                    Debug.trap("Wrong JSON format");
                };
                let #ok time2 = Date.Date.fromIsoFormat(time) else {
                    Debug.trap("Wrong JSON format");
                };
                return Date.Date.toTime(time2);
            }
        };
        Debug.trap("No score");
    };

    public func removeHTTPHeaders(args: Types.TransformArgs): Types.HttpResponsePayload {
        {
            status = args.response.status;
            headers = [];
            body = args.response.body;
        };
    };

    // adopted from https://forum.dfinity.org/t/how-to-convert-text-to-float/15982/2?u=qwertytrewq
    public func textToFloat(t: Text): Float {
        var i : Float = 1;
        var f : Float = 0;
        var isDecimal : Bool = false;

        for (c in t.chars()) {
        if (Char.isDigit(c)) {
            let charToNat : Nat64 = Nat64.fromNat(Nat32.toNat(Char.toNat32(c) -48));
            let natToFloat : Float = Float.fromInt64(Int64.fromNat64(charToNat));
            if (isDecimal) {
                let n : Float = natToFloat / Float.pow(10, i);
            f := f + n;
            } else {
                f := f * 10 + natToFloat;
            };
            i := i + 1;
        } else {
            if (Char.equal(c, '.')) {
                f := f / Float.pow(10, i); // Force decimal
                f := f * Float.pow(10, i); // Correction
                isDecimal := true;
                i := 1;
            } else {
                Debug.trap("NaN");
            };
        };
        };

        return f;
    };
}