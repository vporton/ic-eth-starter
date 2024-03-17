import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import E "mo:candb/Entity";

module {
  /// Person ID for Gitcoin Passport is an Ethereum address.
  public type PersonId = Text;

  public type PersonStorage = {
    personIdPrefix: Text;
    personIdSubkey: E.AttributeKey;
    personPrincipalPrefix: Text;
    personPrincipalSubkey: E.AttributeKey;
  };

  /// Example `PersonStorage`.
  ///
  /// Principal-related information is stored with `up/` prefix in `u` subkey.
  /// Ethereum-address-related information is stored with `ui/` prefix in `u` subkey.
  public let personStorage = {
    personIdPrefix = "ui/";
    personIdSubkey = "u";
    personPrincipalPrefix = "up/";
    personPrincipalSubkey = "u";
  };

  /// Example user record.
  public type User = {
    /// Principal of the user.
    principal: Principal; // TODO: superfluous?
    /// The last recorded Gitcoin Passport personhood score.
    /// We assume that the person is genuine when it is above a certain threshhold (such as `20.0`).
    personhoodScore: Float;
    /// The last date personhood score was recorded.
    /// Personhood is considered genuine, when it was recorded no more than 90 days ago.
    personhoodDate: Time.Time;
    /// The first date personhood score was recorded. It's used together with `lib.adjustVotingPower`.
    firstPersonhoodDate: Time.Time;
    /// The Ethereum address of person confirming personhood.
    personhoodEthereumAddress: Text;
  };

  /// Convert `User` record into `AttributeValue` format.
  public func serializeUser(user: User): E.AttributeValue {
    #tuple([
      #text(Principal.toText(user.principal)),
      #float(user.personhoodScore),
      #int(user.personhoodDate),
      #int(user.firstPersonhoodDate),
      #text(user.personhoodEthereumAddress),
    ]);
  };

  /// Convert `User` record from `AttributeValue` format.
  public func deserializeUser(attr: E.AttributeValue): User {
    var principal = Principal.fromText("2vxsx-fae");
    var score = 0.0;
    var pos = 0;
    var date = +0;
    var firstDate = +0;
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
            case (#int v) {
              firstDate := v;
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
      firstPersonhoodDate = firstDate;
      personhoodEthereumAddress = address;
    };
  };

  /// Every ~3 months add to user's voting power, in order for intruders, that may create
  /// duplicate accounts, have no more votes than legit users.
  ///
  /// This function returns the suggested voting power of a user, to beat intruders.
  public func adjustVotingPower(user: User): Float {
    let passed = Time.now() - user.firstPersonhoodDate;
    let bonus = passed / (1_000_000_000 * 30*24*3600);
    1.0 + Float.fromInt(bonus);
  };
}