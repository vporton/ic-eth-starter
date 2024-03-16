import CA "mo:candb/CanisterActions";
import Entity "mo:candb/Entity";
import CanDB "mo:candb/CanDB";
import E "mo:candb/Entity";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Multi "mo:candb-multi/Multi";
import RBT "mo:stable-rbtree/StableRBTree";
import lib "lib";

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

  // public shared({caller}) func setOwners(_owners: [Principal]): async () {
  // };

  /// @recommended (not required) public API
  public query func getPK(): async Text { db.pk };

  /// @required public API (Do not delete or change)
  public query func skExists(sk: Text): async Bool { 
    CanDB.skExists(db, sk);
  };

  public query func get(options: CanDB.GetOptions): async ?Entity.Entity { 
    CanDB.get(db, options);
  };

  public shared func put(options: CanDB.PutOptions): async () {
    // In real software check access here.

    await* CanDB.put(db, options);
  };

  // TODO: Why here is used `Multi`?
  public shared({caller}) func putAttribute(options: { sk: Entity.SK; subkey: Entity.AttributeKey; value: Entity.AttributeValue }): async () {
    // In real software check access here.
    ignore await* Multi.replaceAttribute(db, options);
  };

  public shared func delete(options: CanDB.DeleteOptions): async () {
    // In real software check access here.

    CanDB.delete(db, options);
  };

  public shared({caller}) func transferCycles(): async () {
    // In real software check access here.

    return await CA.transferCycles(caller);
  };

  public query func getPersonhood(options: CanDB.GetOptions): async lib.User { 
    let sk = lib.personStorage.personPrincipalPrefix # options.sk;
    let ?v = CanDB.get(db, {sk}) else {
      Debug.trap("no such user");
    };
    let ?v2 = RBT.get(v.attributes, Text.compare, lib.personStorage.personPrincipalSubkey) else {
      Debug.trap("no such user");
    };
    lib.deserializeUser(v2);
  };
}