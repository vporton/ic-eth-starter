import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import CA "mo:candb/CanisterActions";
import E "mo:candb/Entity";
import Utils "mo:candb/Utils";
import CanisterMap "mo:candb/CanisterMap";
import Buffer "mo:StableBuffer/StableBuffer";
import CanDBPartition "CanDBPartition";
import Admin "mo:candb/CanDBAdmin";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Multi "mo:candb-multi/Multi";
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

  /// Stores user info (normally, user's principal and identity score) in the DB.
  /// The user is identified by `personId` (Ethereum address for Gitcoin Passport).
  /// This function ensures that no duplicate persons are created.
  func _storePersonhood({
    map: CanisterMap.CanisterMap;
    pk: E.PK;
    personId: Text;
    personPrincipal: Principal;
    personIdStoragePrincipal: ?Principal;
    personStoragePrincipal: ?Principal;
    userInfo: E.AttributeValue;
    storage: lib.PersonStorage;
  }) : async* { personIdStoragePrincipal: Principal; personStoragePrincipal: Principal } {
    // TODO: Order of the next two operations?
    // NoDuplicates, because it cannot be more than one personhood with a given address.
    let oldIdV = await* Multi.getAttributeByHint(
      map,
      pk,
      personIdStoragePrincipal,
      { sk = storage.personIdPrefix # personId; subkey = storage.personIdSubkey }
    );
    let personPrincipalText = Principal.toText(personPrincipal);

    // Nullify the previous Ethereum address:
    switch (oldIdV) {
      case (?(_, ?#text attr)) {
        if (attr != personPrincipalText) {
          // let personPrincipalCanister: CanDBPartition.CanDBPartition = actor(personPrincipalText);
          switch (await* Multi.getAttributeByHint(pkToCanisterMap, pk, personStoragePrincipal, {
              sk = storage.personPrincipalPrefix # personPrincipalText;
              subkey = storage.personPrincipalSubkey;
          })) {
            case (?(_, ?oldUserInfo)) {
              var oldUser = lib.deserializeUser(oldUserInfo);
              let oldUserUpdated = {
                principal = oldUser.principal;
                personhoodScore = 0.0;
                personhoodDate = 0;
                firstPersonhoodDate = oldUser.firstPersonhoodDate;
                personhoodEthereumAddress = oldUser.personhoodEthereumAddress;
              };
              ignore await* Multi.putAttributeNoDuplicates(
                map,
                pk,
                personStoragePrincipal,
                {
                  sk = storage.personPrincipalPrefix # personPrincipalText;
                  subkey = storage.personPrincipalSubkey;
                  value = lib.serializeUser(oldUserUpdated);
                },
              );
            };
            case _ {};
          };
        };
      };
      case _ {};
    };

    let personIdResult = await* Multi.putAttributeNoDuplicates(
      map,
      pk,
      personIdStoragePrincipal,
      {
        sk = storage.personIdPrefix # personId;
        subkey = storage.personIdSubkey;
        value = #text(personPrincipalText);
      },
    );
    // NoDuplicates, because there can't be more than one user with a given principal.
    let personPrincipalResult = await* Multi.putAttributeNoDuplicates(
      map,
      pk,
      personStoragePrincipal,
      {
        sk = storage.personPrincipalPrefix # personPrincipalText;
        subkey = storage.personPrincipalSubkey;
        value = userInfo;
      },
    );
    { personIdStoragePrincipal = personIdResult; personStoragePrincipal = personPrincipalResult };
  };

  public shared func getAttributeByHint({
    pk: E.PK;
    hint: ?Principal;
    options: { sk: E.SK; subkey: E.AttributeKey };
  }): async ?(Principal, ?E.AttributeValue) {
    // In real code you have authorization here.

    await* Multi.getAttributeByHint(pkToCanisterMap, pk, hint, options);
  };

  public shared({caller}) func storePersonhood({
    /// PK for personhood data.
    pk: E.PK;
    /// The IC principal to which the user is bound.
    personPrincipal: Principal;
    /// The hint of canister where `User` data should be stored (under `personPrincipal` as the SK).
    personStoragePrincipal: ?Principal;
    /// The hint of canister where mapping from the Ethereum address to the principal should be stored (under `ethereumAddress` as the SK).
    personIdStoragePrincipal: ?Principal;
    /// Personhood score.
    score: Float;
    /// The time of personhood score.
    time: Time.Time;
    /// The Ethereum address of the person.
    ethereumAddress: Text;
  }) : async { personIdStoragePrincipal: Principal; personStoragePrincipal: Principal }
  {
    // In real code you have authorization here.

    let oldUser = await* Multi.getAttributeByHint(pkToCanisterMap, pk, personStoragePrincipal, {
      sk = lib.personStorage.personPrincipalPrefix # Principal.toText(personPrincipal);
      subkey = lib.personStorage.personPrincipalSubkey;
    });
    let firstDate = switch (oldUser) {
      case (?(oldUser, ?v)) {
        lib.deserializeUser(v).firstPersonhoodDate;
      };
      case _ { 0 };
    };
    let oldUserUpdated = {
      principal = caller;
      personhoodScore = score;
      personhoodDate = time;
      firstPersonhoodDate = firstDate;
      personhoodEthereumAddress = ethereumAddress;
    };
    let oldUserEntity = lib.serializeUser(oldUserUpdated);
    switch (personStoragePrincipal) {
      case (?personStoragePrincipal) {
        let part: CanDBPartition.CanDBPartition = actor(Principal.toText(personStoragePrincipal));
        await part.putAttribute({
          sk = lib.personStorage.personPrincipalPrefix # Principal.toText(personPrincipal);
          value = oldUserEntity;
          subkey = lib.personStorage.personPrincipalSubkey;
        });
      };
      case null {};
    };
    let user = {
      principal = caller;
      personhoodScore = score;
      personhoodDate = time;
      firstPersonhoodDate = if (firstDate == 0) { time } else { firstDate };
      personhoodEthereumAddress = ethereumAddress;
    };
    let userEntity = lib.serializeUser(user);
    await* _storePersonhood({
      map = pkToCanisterMap;
      pk = "user";
      personId = user.personhoodEthereumAddress;
      personPrincipal;
      personStoragePrincipal;
      personIdStoragePrincipal;
      userInfo = userEntity;
      storage = lib.personStorage;
    });
  };
}