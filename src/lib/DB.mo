import E "mo:candb/Entity";
import CanisterMap "mo:candb/CanisterMap";
import Multi "mo:candb-multi/Multi";
import Principal "mo:base/Principal";

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
        hint: ?Principal;
        personId: Text;
        personStoragePrincipal: Principal;
        userInfo: E.AttributeValue;
        storage: PersonStorage;
    }) : async* { personIdPrincipal: Principal; personStoragePrincipal: Principal } {
        // TODO: Order of the next two operations?
        // NoDuplicates, because it cannot be more than one personhood with a given address.
        let personIdResult = await* Multi.putAttributeNoDuplicates(
            map,
            pk,
            hint,
            {
                sk = storage.personIdPrefix # personId;
                subkey = storage.personIdSubkey;
                value = userInfo;
            },
        );
        // NoDuplicates, because there can't be more than one user with a given principal.
        let personPrincipalResult = await* Multi.putAttributeNoDuplicates(
            map,
            pk,
            hint,
            {
                sk = storage.personPrincipalPrefix # Principal.toText(personStoragePrincipal);
                subkey = storage.personPrincipalSubkey;
                value = #text personId;
            },
        );
        { personIdPrincipal = personIdResult; personStoragePrincipal = personPrincipalResult };
    }
}