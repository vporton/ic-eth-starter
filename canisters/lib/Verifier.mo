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

module {
    public type EthereumAddress = Blob;

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

    /// Remember to add cycles for the HTTP request.
    public func scoreByEthereumAddress(
        address: Text,
        scorerId: Nat,
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload,
    ): async* Float {
        let ic : Types.IC = actor ("aaaaa-aa"); // management canister

        let request : Types.HttpRequestArgs = {
            body = null;
            headers = []; // FIXME: API KEY
            max_response_bytes = ?10000;
            method = #get;
            url = "https://api.scorer.gitcoin.co/registry/score/" # Nat.toText(scorerId) # "/" # address; // TODO: Configurable URL
            transform = ?{
                function = transform;
                context = Blob.fromArray([]);
            };
        };

        let response: Types.HttpResponsePayload = await ic.http_request(request);
        let ?body = Text.decodeUtf8(Blob.fromArray(response.body)) else {
            Debug.trap("scorer response is not UTF-8");
        };
        let ?json = JSON.parse(body) else {
            Debug.trap("scorer response is not JSON");
        };

        let scoreOption = label b: ?Text {
            let #Object jsonObject = json else {
                break b null;
            };
            for (e in jsonObject.vals()) {
                if (e.0 == "items") {
                    let #Array items = e.1 else {
                        break b null;
                    };
                    let #Object item = items[0] else {
                        break b null;
                    };
                    for (e in item.vals()) {
                        if (e.0 == "address") {
                            let #String address = e.1 else { // FIXME: It may be null.
                                break b null;
                            };
                            break b (?address);
                        };
                    };
                } else {
                    break b null;
                };
            };
            null;
        };
        let ?score = scoreOption else {
            Debug.trap("Unsupported JSON format");
        };
        0.0; //textToFloat(score); // FIXME
    };

    // TODO: Signature - text or blob?
    /// Remember to add cycles for the HTTP request.
    public func scoreBySignedEthereumAddress(
        address: Text,
        signature: Text,
        scorerId: Nat,
        transform: shared query Types.TransformArgs -> async Types.HttpResponsePayload,
    ): async* Float {
        let message = "I certify that I am the owner of the Ethereum account\n" # address;
        if (not(await ic_eth.verify_ecdsa(address, message, signature))) {
            Debug.trap("You are not the owner of the Ethereum account");
        };
        await* scoreByEthereumAddress(address, scorerId, transform);
    };

    public func scoreHTTPTransform(args: Types.TransformArgs): Types.HttpResponsePayload {
        {
            status = args.response.status;
            headers = [];
            body = args.response.body;
        };
    };

    // adopted from https://forum.dfinity.org/t/how-to-convert-text-to-float/15982/2?u=qwertytrewq
    public func textToFloat(t: Text) : async Float {
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
                throw Debug.trap("NaN");
            };
        };
        };

        return f;
    };
}