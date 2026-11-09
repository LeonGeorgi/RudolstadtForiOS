import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FriendError, requireValue } from "./protocol.js";
import { syncOwnerRecords } from "./owner-profile.js";
import { getAuth } from "firebase-admin/auth";
import { globalFriendFunctions } from "./global-friends.js";
import { accountKeyFunctions } from "./account-keys.js";
import { accountDeletionFunctions } from "./account-deletion.js";

initializeApp();
const db = getFirestore();
const options = { region: "europe-west3", maxInstances: 3 };

export const { createKeyAccount, signInWithAccountKey, accountKeyStatus, replaceAccountKey } =
  accountKeyFunctions(db, getAuth(), options);
export const { setFriendIdentity, publishFriendProfile, createFriendInvite, previewFriendInvite, acceptFriendInvite, updateFriendSharing, friendConnectionStatus, removeFriend } = globalFriendFunctions(db, options);
export const { deleteAccount, accountDeletionStatus, eraseDeletedAccount, finishAccountDeletions } = accountDeletionFunctions(db, options);

function callable(handler) {
  return onCall(options, async request => {
    try {
      requireValue(request.auth && request.auth.token.firebase?.sign_in_provider !== "anonymous", "unauthenticated");
      requireValue(!(await db.collection("accountDeletions").doc(request.auth.uid).get()).exists, "permission-denied");
      const edition = request.data?.edition;
      requireValue(typeof edition === "string" && /^[a-z][a-z0-9-]{0,50}-[0-9]{4}$/.test(edition));
      return await handler(request.auth.uid, edition, request.data);
    } catch (error) {
      if (error instanceof FriendError) throw new HttpsError(error.code, error.message);
      throw error;
    }
  });
}

export const syncOwnProfile = callable(async (uid, edition, data) => {
  // Bind an in-flight device request to its original account even if the SDK's
  // authentication changes before obtaining the callable token.
  requireValue(data.owner === uid, "permission-denied");
  requireValue(data.archiveSharing === undefined ||
    (data.archiveSharing === true && /^rudolstadt-[0-9]{4}$/.test(edition)));
  return syncOwnerRecords(db, uid, edition, data.records, data.archiveSharing === true);
});

