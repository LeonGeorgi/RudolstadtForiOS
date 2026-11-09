package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.profile.*
import kotlin.test.*

class FriendSharingTests {
    private val invite = FriendInvite("a".repeat(43))

    @Test
    fun globalInvitationsRoundTripAndRejectOldOrUntrustedLinks() {
        assertEquals(invite, FriendSharing.parseInvite(invite.url))
        for (url in
            listOf(
                invite.url.replace("https:", "http:"),
                invite.url.replace("festival.leongeorgi.de", "example.org"),
                invite.url + "&token=" + "b".repeat(43),
                invite.url + "&edition=rudolstadt-2026",
                invite.url.replace("v=2", "v=1"),
                invite.url + "&v=2",
                invite.url + "#fragment",
                "https://festival.leongeorgi.de/rudolstadt/friends?edition=rudolstadt-2026&token=${invite.token}",
            )) assertNull(FriendSharing.parseInvite(url), url)
    }

    @Test
    fun publicationExcludesPrivateNotesAndIdentityAndPreservesOnlyAllowedDataKinds() {
        val owner =
            PersonalProfile(
                badgeName = "Alex",
                savedEventIDs = listOf(3, 1, 3),
                artistPreferences = listOf(ArtistPreference(12, 3)),
                artistNotes = listOf(ArtistNote(12, "PRIVATE SECRET")),
            )
        val payload = FriendSharing.encode(owner)
        assertFalse(payload.contains("PRIVATE"))
        assertFalse(payload.contains("artistNotes"))
        assertFalse(payload.contains("Alex"))
        val data = FriendSharing.data(payload)
        assertEquals(listOf(1L, 3L), data.savedEventIDs)
        assertEquals(owner.artistPreferences, data.artistPreferences)
    }

    @Test
    fun defaultPermissionsExposeNeitherFestivalCategory() {
        assertFalse(FriendPermissions().savedEvents)
        assertFalse(FriendPermissions().ratings)
        assertFalse(FriendPermissions().notes)
        assertEquals(emptyList(), FriendSharing.data("{}").savedEventIDs)
        val result =
            FriendSharing.profile(
                "uid",
                "other-festival-2027",
                FriendIdentity("Alex", 210.0),
                listOf(42),
                emptyList(),
            )
        assertEquals("Alex", result.title)
        assertEquals(2027, result.year)
        assertEquals(listOf(42L), result.saved)
    }
}
