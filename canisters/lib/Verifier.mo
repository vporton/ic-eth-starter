import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Char "mo:base/Char";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import ic_eth "canister:ic_eth";
import Types "./Types";
import JSON "mo:json.mo/JSON";
import Parser "mo:parser-combinators/Parser";
import Config "../../Config";

module {
    public type EthereumAddress = Blob;

    let ic : Types.IC = actor ("aaaaa-aa"); // management canister

    func _toLowerHexDigit(v: Nat): Char {
        Char.fromNat32(Nat32.fromNat(
        if (v < 10) {
            Nat32.toNat(Char.toNat32('0')) + v;
        } else {
            Nat32.toNat(Char.toNat32('a')) + v - 10;
        }
        ));
    };

    func encodeHex(g: Blob): Text {
        var result = "";
        for (b in g.vals()) {
            let b2 = Nat8.toNat(b);
                result #= Text.fromChar(_toLowerHexDigit(b2 / 16)) # Text.fromChar(_toLowerHexDigit(b2 % 16));
            };
        result;
    };

    func obtainSuccessfulResponse(request: Types.HttpRequestArgs): async* Text {
        Cycles.add(20_000_000);
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

    public func checkAddressOwner({address: Text; signature: Text; nonce: Text}): async* () {
        // the same text as returned by `GET /registry/signing-message`
        let message = "I hereby agree to submit my address in order to score my associated Gitcoin Passport from Ceramic.\n\nNonce: "
            # nonce # "\n";
        if (not(await ic_eth.verify_ecdsa(address, message, signature))) {
            Debug.trap("You are not the owner of the Ethereum account");
        };
    };

    public func scoreByEthereumAddress({
        address: Text;
        scorerId: Nat;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
    }): async* Text {
        let request : Types.HttpRequestArgs = {
            body = null;
            headers = [{name = "X-API-KEY"; value = Config.scorerAPIKey}];
            max_response_bytes = ?10000;
            method = #get;
            url = Config.scorerUrl # "/registry/score/" # Nat.toText(scorerId) # "/" # address;
            transform = ?{
                function = transform;
                context = Blob.fromArray([]);
            };
        };
        await* obtainSuccessfulResponse(request);
    };

    public func scoreBySignedEthereumAddress({
        address: Text;
        signature: Text;
        nonce: Text;
        scorerId: Nat;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
    }): async* Text {
        await* checkAddressOwner({address; signature; nonce});
        await* scoreByEthereumAddress({address; scorerId; transform});
    };

    public func submitEthereumAddressForScore({
        address: Text;
        scorerId: Nat;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
    }): async* Text {
        let requestBody = JSON.show(
            #Object ([
                ("address", #String address),
                ("scorer_id", #String(Nat.toText(scorerId))),
                // ("signature", #String TODO),
                // ("nonce", #String TODO),
            ]),
        );
        let request : Types.HttpRequestArgs = {
            body = ?(Blob.toArray(Text.encodeUtf8(requestBody)));
            headers = [
                {name = "X-API-KEY"; value = Config.scorerAPIKey},
                {name = "Content-Type"; value = "application/json"},
            ];
            max_response_bytes = ?10000;
            method = #post;
            url = Config.scorerUrl # "/registry/submit-passport";
            transform = ?{
                function = transform;
                context = Blob.fromArray([]);
            };
        };
        await* obtainSuccessfulResponse(request);
    };

    public func getEthereumSigningMessage({
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
    }): async* {message: Text; nonce: Text} {
        let request : Types.HttpRequestArgs = {
            body = null;
            headers = [
                {name = "X-API-KEY"; value = Config.scorerAPIKey},
            ];
            max_response_bytes = ?10000;
            method = #get;
            url = Config.scorerUrl # "/registry/signing-message";
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
        address: Text;
        signature: Text;
        nonce: Text;
        scorerId: Nat;
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload;
    }): async* Text {
        await* checkAddressOwner({address; signature; nonce});
        await* submitEthereumAddressForScore({address; scorerId; transform});
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
                // Someone claimed, that scorer returns `"0E-9"` if zero score:
                if (score == "0E-9") {
                    return 0.0;
                };
                return textToFloat(score);
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