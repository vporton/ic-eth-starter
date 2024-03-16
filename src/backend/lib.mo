import Time "mo:base/Time";
import Principal "mo:base/Principal";
import E "mo:candb/Entity";

module {
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


}