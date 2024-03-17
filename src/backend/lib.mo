import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import E "mo:candb/Entity";

module {
  public let personStorage = {
    personIdPrefix = "ui/";
    personIdSubkey = "u";
    personPrincipalPrefix = "up/";
    personPrincipalSubkey = "u";
  };

  public type User = {
    principal: Principal;
    personhoodScore: Float;
    personhoodDate: Time.Time;
    personhoodEthereumAddress: Text;
  };

  public func serializeUser(user: User): E.AttributeValue {
    #tuple([
      #text(Principal.toText(user.principal)),
      #float(user.personhoodScore),
      #int(user.personhoodDate),
      #text(user.personhoodEthereumAddress),
    ]);
  };

  public func deserializeUser(attr: E.AttributeValue): User {
    var principal = Principal.fromText("2vxsx-fae");
    var score = 0.0;
    var pos = 0;
    var date = +0;
    var address = "";
    let res = label r: Bool {
      switch (attr) {
        case (#tuple attr) {
          switch (attr[pos]) {
            case (#text v) {
              principal := Principal.fromText(v);
              pos += 1;
            };
            case _ { break r false; };
          };
          switch (attr[pos]) {
            case (#float v) {
              score := v;
              pos += 1;
            };
            case _ { break r false; };
          };
          switch (attr[pos]) {
            case (#int v) {
              date := v;
              pos += 1;
            };
            case _ { break r false; };
          };
          switch (attr[pos]) {
            case (#text v) {
              address := v;
              pos += 1;
            };
            case _ { break r false; };
          };
        };
        case _ { break r false };
      };
      true;
    };
    if (not res) {
      Debug.trap("wrong user format");
    };
    {
      principal;
      personhoodScore = score;
      personhoodDate = date;
      personhoodEthereumAddress = address;
    };
  };

  /// Person ID for Gitcoin Passport is an Ethereum address
  public type PersonId = Text;

  public type PersonStorage = {
    personIdPrefix: Text;
    personIdSubkey: E.AttributeKey;
    personPrincipalPrefix: Text;
    personPrincipalSubkey: E.AttributeKey;
  };

  /// Every ~3 months add to user's score in order for intruders, that may create
  /// duplicate accounts, have no more votes than legit users.
  public func adjustVotingPower(user: User): Float {
    let passed = Time.now() - user.personhoodDate; // FIXME: Need the FIRST submit date.
    let bonus = passed / (1_000_000_000 * 30*24*3600);
    1.0 + Float.fromInt(bonus);
  };
}