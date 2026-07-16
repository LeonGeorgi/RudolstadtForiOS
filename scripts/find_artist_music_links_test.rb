#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "find_artist_music_links"

class FindArtistMusicLinksTest < Minitest::Test
  Artist = ArtistMusicLinks::FestivalArtist
  Candidate = ArtistMusicLinks::Candidate
  Resource = ArtistMusicLinks::URLs::AppleResource

  def test_parses_apple_artist_album_and_song_urls
    artist = ArtistMusicLinks::URLs.apple_resource(
      "https://music.apple.com/de/artist/duga/1708157322?l=en"
    )
    album = ArtistMusicLinks::URLs.apple_resource(
      "https://music.apple.com/lv/album/visu-gadu-dziesmas-kr%C4%81ju-ep/1776392876"
    )

    assert_equal ["artist", "1708157322"], [artist.kind, artist.id]
    assert_equal ["album", "1776392876"], [album.kind, album.id]
  end

  def test_normalizes_binary_encoded_website_content
    binary = "Bassline".dup.force_encoding(Encoding::ASCII_8BIT)

    assert_equal "bassline", ArtistMusicLinks::Text.normalize(binary)
  end

  def test_exact_apple_name_alone_still_requires_review
    candidate = candidate_for("Ilar", source: "apple_search")
    candidate.merge_metadata(albums: ["My One and Only - Single"])

    ArtistMusicLinks::Scorer.new.score(
      candidate,
      festival_artist("Ilar", description: "Pop, jazz and folk songs")
    )

    assert_equal 40, candidate.score
    assert_equal "review", candidate.confidence
  end

  def test_official_website_and_exact_name_are_verified
    candidate = candidate_for("Duo Ruut", source: "official_website")

    ArtistMusicLinks::Scorer.new.score(candidate, festival_artist("Duo Ruut"))

    assert_equal 90, candidate.score
    assert_equal "verified", candidate.confidence
  end

  def test_album_and_credited_artists_in_description_raise_score
    artist = festival_artist(
      "Bentu",
      description: "Badi Assad and Sérgio Pererê joined forces for the album Bentu."
    )
    candidate = Candidate.new(Resource.new(kind: "album", id: "1772362429", url: "example"))
    candidate.add_source("apple_search")
    candidate.merge_metadata(
      name: "Sérgio Pererê & Badi Assad",
      genre: "MPB",
      albums: ["Bentu"]
    )

    ArtistMusicLinks::Scorer.new.score(candidate, artist)

    assert_operator candidate.score, :>=, 65
    assert_includes %w[likely verified], candidate.confidence
  end

  def test_distinctive_catalog_word_supports_an_exact_name_candidate
    artist = festival_artist(
      "Duga",
      description: "The Swedish group released their debut EP Ørf in 2024."
    )
    candidate = candidate_for("Duga", source: "apple_search")
    candidate.merge_metadata(genre: "Traditional Folk", albums: ["Ørf-Our - EP"])

    ArtistMusicLinks::Scorer.new.score(candidate, artist)

    assert_operator candidate.score, :>=, 60
  end

  def test_catalog_suffix_does_not_hide_a_description_title_match
    artist = festival_artist(
      "Bille",
      description: "The programme is entitled Visu gadu dziesmas krāju."
    )
    candidate = Candidate.new(Resource.new(kind: "album", id: "2", url: "example"))
    candidate.add_source("apple_search")
    candidate.merge_metadata(
      name: "Liene Skrebinska, Anna Patrīcija Karele & Katrīna Karele",
      genre: "Folk",
      albums: ["Visu gadu dziesmas krāju - EP"]
    )

    ArtistMusicLinks::Scorer.new.score(candidate, artist)

    assert candidate.evidence.any? { |item| item.include?("Albumtitel aus der Festivalbeschreibung") }
  end

  def test_artist_name_in_description_is_not_mistaken_for_an_album_reference
    artist = festival_artist(
      "Make A Move",
      description: "Make A Move is an electrifying live act with heavy beats."
    )
    candidate = Candidate.new(Resource.new(kind: "album", id: "2", url: "wrong"))
    candidate.add_source("apple_search")
    candidate.merge_metadata(
      name: "ILYAA & Rebecca Helena",
      genre: "Electronic",
      albums: ["Make A Move - Single"]
    )

    ArtistMusicLinks::Scorer.new.score(candidate, artist)

    refute candidate.evidence.any? { |item| item.include?("Albumtitel aus der Festivalbeschreibung") }
    refute candidate.evidence.any? { |item| item.include?("gleichnamiges Album") }
    assert_operator candidate.score, :<, 40
  end

  def test_first_artist_result_with_catalog_match_on_website_is_likely
    artist = festival_artist("Make A Move", website_text: "Bassline HOL MICH AB")
    candidate = candidate_for("Make a Move", source: "apple_artist_search")
    candidate.apple_search_rank = 1
    candidate.merge_metadata(albums: ["Bassline - Single", "Gib Dir - EP"])

    ArtistMusicLinks::Scorer.new.score(candidate, artist)

    assert_operator candidate.score, :>=, 65
    assert_equal "likely", candidate.confidence
    assert candidate.evidence.any? { |item| item.include?("offiziellen Website") }
  end

  def test_artist_name_is_not_used_as_a_distinctive_catalog_keyword
    artist = festival_artist("Bille", description: "The Latvian trio Bille performs folk music.")
    candidate = candidate_for("Bille", source: "apple_artist_search")
    candidate.apple_search_rank = 4
    candidate.merge_metadata(albums: ["A Track Featuring Bille"])

    ArtistMusicLinks::Scorer.new.score(candidate, artist)

    refute candidate.evidence.any? { |item| item.include?("Katalogbegriff") }
    assert_operator candidate.score, :<, 65
  end

  def test_featured_artist_credits_are_not_used_as_catalog_keywords
    artist = festival_artist("Bille", description: "The trio comes from the south of Latvia.")
    candidate = candidate_for("Bille", source: "apple_artist_search")
    candidate.apple_search_rank = 4
    candidate.merge_metadata(albums: ["Compilation (feat. Shorty South, Bille & Others)"])

    ArtistMusicLinks::Scorer.new.score(candidate, artist)

    refute candidate.evidence.any? { |item| item.include?("Katalogbegriff") }
    assert_operator candidate.score, :<, 65
  end

  private

  def candidate_for(name, source:)
    candidate = Candidate.new(Resource.new(kind: "artist", id: "1", url: "example"))
    candidate.add_source(source)
    candidate.merge_metadata(name: name)
    candidate
  end

  def festival_artist(name, description: "", website_text: "")
    Artist.new(
      id: 1,
      name: name,
      country: "DEU",
      website: "",
      facebook: "",
      instagram: "",
      description: description,
      website_text: website_text
    )
  end
end
