import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import CA "mo:candb/CanisterActions";
import Utils "mo:candb/Utils";
import CanisterMap "mo:candb/CanisterMap";
import Buffer "mo:StableBuffer/StableBuffer";
import CanDBPartition "CanDBPartition";
import Admin "mo:candb/CanDBAdmin";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import DB "../lib/DB";
import lib "lib";

shared({caller = initialOwner}) actor class () = this {
  stable var initialized: Bool = false;

  stable var owners: [Principal] = [];

  func ownersOrSelf(): [Principal] {
    let buf = Buffer.fromArray<Principal>(owners);
    Buffer.add(buf, Principal.fromActor(this));
    Buffer.toArray(buf);
  };

  public shared func init(_owners: [Principal]): async () {
    if (initialized) {
      Debug.trap("already initialized");
    };

    owners := _owners;

    ignore await* createStorageCanister("user", ownersOrSelf()); // user data

    initialized := true;
  };

  let maxSize = #heapSize(500_000_000);

  stable var pkToCanisterMap = CanisterMap.init();

  /// @required API (Do not delete or change)
  ///
  /// Get all canisters for an specific PK
  ///
  /// This method is called often by the candb-client query & update methods. 
  public shared query func getCanistersByPK(pk: Text): async [Text] {
    getCanisterIdsIfExists(pk);
  };
  
  /// @required function (Do not delete or change)
  ///
  /// Helper method acting as an interface for returning an empty array if no canisters
  /// exist for the given PK
  func getCanisterIdsIfExists(pk: Text): [Text] {
    switch(CanisterMap.get(pkToCanisterMap, pk)) {
      case null { [] };
      case (?canisterIdsBuffer) { Buffer.toArray(canisterIdsBuffer) } 
    }
  };

  /// This hook is called by CanDB for AutoScaling the User Service Actor.
  ///
  /// If the developer does not spin up an additional User canister in the same partition within this method, auto-scaling will NOT work
  /// Upgrade user canisters in a PK range, i.e. rolling upgrades (limit is fixed at upgrading the canisters of 5 PKs per call)
  public shared func upgradeAllPartitionCanisters(wasmModule: Blob): async Admin.UpgradePKRangeResult {
    // In real software check access here.

    await Admin.upgradeCanistersInPKRange({
      canisterMap = pkToCanisterMap;
      lowerPK = "";
      upperPK = "\u{FFFF}";
      limit = 5;
      wasmModule = wasmModule;
      scalingOptions = {
        autoScalingHook = autoScaleCanister;
        sizeLimit = maxSize;
      };
      owners = ?ownersOrSelf();
    });
  };

  public shared({caller}) func autoScaleCanister(pk: Text): async Text {
    // In real software check access here.

    if (Utils.callingCanisterOwnsPK(caller, pkToCanisterMap, pk)) {
      await* createStorageCanister(pk, ownersOrSelf());
    } else {
      Debug.trap("error, called by non-controller=" # debug_show(caller));
    };
  };

  func createStorageCanister(pk: Text, controllers: [Principal]): async* Text {
    Debug.print("creating new storage canister with pk=" # pk);
    // Pre-load 300 billion cycles for the creation of a new storage canister
    // Note that canister creation costs 100 billion cycles, meaning there are 200 billion
    // left over for the new canister when it is created
    Cycles.add<system>(210_000_000_000); // TODO: Choose the number.
    let newStorageCanister = await CanDBPartition.CanDBPartition({
      partitionKey = pk;
      scalingOptions = {
        autoScalingHook = autoScaleCanister;
        sizeLimit = maxSize;
      };
      owners = ?controllers;
    });
    let newStorageCanisterPrincipal = Principal.fromActor(newStorageCanister);
    await CA.updateCanisterSettings({
      canisterId = newStorageCanisterPrincipal;
      settings = {
        controllers = ?controllers;
        compute_allocation = ?0;
        memory_allocation = ?0;
        freezing_threshold = ?2592000;
      }
    });

    let newStorageCanisterId = Principal.toText(newStorageCanisterPrincipal);
    pkToCanisterMap := CanisterMap.add(pkToCanisterMap, pk, newStorageCanisterId);

    Debug.print("new storage canisterId=" # newStorageCanisterId);
    newStorageCanisterId;
  };

  // Private functions for getting canisters //

  // func lastCanister(pk: Entity.PK): async* CanDBPartition.CanDBPartition {
  //   let canisterIds = getCanisterIdsIfExists(pk);
  //   let part0 = if (canisterIds == []) {
  //     await* createStorageCanister(pk, ownersOrSelf());
  //   } else {
  //     canisterIds[canisterIds.size() - 1];
  //   };
  //   actor(part0);
  // };

  // func getExistingCanister(pk: Entity.PK, options: CanDB.GetOptions, hint: ?Principal): async* ?CanDBPartition.CanDBPartition {
  //   switch (hint) {
  //     case (?hint) {
  //       let canister: CanDBPartition.CanDBPartition = actor(Principal.toText(hint));
  //       if (await canister.skExists(options.sk)) {
  //         return ?canister;
  //       } else {
  //         Debug.trap("wrong DB partition hint");
  //       };
  //     };
  //     case null {};
  //   };

  //   // Do parallel search in existing canisters:
  //   let canisterIds = getCanisterIdsIfExists(pk);
  //   let threads : [var ?(async())] = Array.init(canisterIds.size(), null);
  //   var foundInCanister: ?Nat = null;
  //   for (threadNum in threads.keys()) {
  //     threads[threadNum] := ?(async {
  //       let canister: CanDBPartition.CanDBPartition = actor(canisterIds[threadNum]);
  //       switch (foundInCanister) {
  //         case (?foundInCanister) {
  //           if (foundInCanister < threadNum) {
  //             return; // eliminate unnecessary work.
  //           };
  //         };
  //         case null {};
  //       };
  //       if (await canister.skExists(options.sk)) {
  //         foundInCanister := ?threadNum;
  //       };
  //     });
  //   };
  //   for (topt in threads.vals()) {
  //     let ?t = topt else {
  //       Debug.trap("programming error: threads");
  //     };
  //     await t;
  //   };

  //   switch (foundInCanister) {
  //     case (?foundInCanister) {
  //       ?(actor(canisterIds[foundInCanister]): CanDBPartition.CanDBPartition);
  //     };
  //     case null {
  //       let newStorageCanisterId = await* createStorageCanister(pk, ownersOrSelf());
  //       ?(actor(newStorageCanisterId): CanDBPartition.CanDBPartition);
  //     };
  //   };
  // };

  // Personhood //

  let personStorage = {
    personIdPrefix = "ui/";
    personIdSubkey = "u";
    personPrincipalPrefix = "up/";
    personPrincipalSubkey = "u";
  };

  public shared({caller}) func storePersonhood(hint: ?Principal, score: Float, ethereumAddress: Text)
    : async { personIdPrincipal: Principal; personPrincipal: Principal }
  {
    let user = {
      principal = caller;
      personhoodScore = score;
      personhoodDate = Time.now();
      personhoodEthereumAddress = ethereumAddress;
    };
    let userEntity = lib.serializeUser(user);
    await* DB.storePersonhood({
      map = pkToCanisterMap;
      pk = "user";
      hint;
      personId = user.personhoodEthereumAddress;
      personPrincipal = user.principal;
      userInfo = userEntity;
      storage = personStorage;
    });
  };
}