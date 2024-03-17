import E "mo:candb/Entity";
import CanisterMap "mo:candb/CanisterMap";
import Multi "mo:candb-multi/Multi";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import CanDBPartition "../backend/CanDBPartition";
import CanDBIndex "canister:CanDBIndex";

module {
    /// Person ID for Gitcoin Passport is an Ethereum address
    public type PersonId = Text;

    public type PersonStorage = {
        personIdPrefix: Text;
        personIdSubkey: E.AttributeKey;
        personPrincipalPrefix: Text;
        personPrincipalSubkey: E.AttributeKey;
    };

    /// Stores user info (normally, user's principal and identity score) in the DB.
    /// The user is identified by `personId` (Ethereum address for Gitcoin Passport).
    /// This function ensures that no duplicate persons are created.
    public func storePersonhood({
        map: CanisterMap.CanisterMap;
        pk: E.PK;
        personId: Text;
        personIdStoragePrincipal: ?Principal;
        personPrincipal: Principal;
        personStoragePrincipal: ?Principal;
        userInfo: E.AttributeValue;
        storage: PersonStorage;
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
        // FIXME: Nullify the previous Ethereum address.
        switch (oldIdV) {
            case (?(_, ?#text attr)) {
                if (attr != personPrincipalText) {
                    let personPrincipalCanister: CanDBPartition.CanDBPartition = actor(personPrincipalText);
                    var oldUser = CanDBIndex.getAttributeByHint(pk, personPrincipalCanister, {
                        sk = storage.personPrincipalPrefix # personPrincipalText;
                        subkey = storage.personPrincipalSubkey;
                    });
                    oldUser.score := 0;
                    CanDBIndex.storePersonhood(oldUser);
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
    }
}