import CA "mo:candb/CanisterActions";
import Entity "mo:candb/Entity";
import CanDB "mo:candb/CanDB";
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";
import Text "mo:base/Text";

shared actor class CanDBPartition(options: {
  partitionKey: Text;
  scalingOptions: CanDB.ScalingOptions;
}) = this {
  /// @required (may wrap, but must be present in some form in the canister)
  stable let db = CanDB.init({
    pk = options.partitionKey;
    scalingOptions = options.scalingOptions;
    btreeOrder = null;
  });

  public shared({caller}) func setOwners(_owners: [Principal]): async () {
  };

  /// @recommended (not required) public API
  public query func getPK(): async Text { db.pk };

  /// @required public API (Do not delete or change)
  public query func skExists(sk: Text): async Bool { 
    CanDB.skExists(db, sk);
  };

  public query func get(options: CanDB.GetOptions): async ?Entity.Entity { 
    CanDB.get(db, options);
  };

  public shared({caller}) func put(options: CanDB.PutOptions): async () {
    // In real software check access here.

    await* CanDB.put(db, options);
  };

  public shared({caller}) func delete(options: CanDB.DeleteOptions): async () {
    // In real software check access here.

    CanDB.delete(db, options);
  };

  public shared({caller}) func transferCycles(): async () {
    // In real software check access here.

    return await CA.transferCycles(caller);
  };
}