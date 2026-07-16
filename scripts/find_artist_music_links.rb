#!/usr/bin/env ruby

require "cgi"
require "csv"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "optparse"
require "set"
require "time"
require "uri"

module ArtistMusicLinks
  USER_AGENT = "RudolstadtArtistLinkFinder/1.0 (https://github.com/LeonGeorgi/RudolstadtForiOS)"

  COUNTRY_CODES = {
    "ARG" => "AR", "AUS" => "AU", "AUT" => "AT", "BGR" => "BG",
    "BRA" => "BR", "CAN" => "CA", "CZE" => "CZ", "DEN" => "DK",
    "DEU" => "DE", "ENG" => "GB", "EST" => "EE", "FIN" => "FI",
    "FRA" => "FR", "GBR" => "GB", "GTM" => "GT", "IND" => "IN",
    "IRL" => "IE", "IRN" => "IR", "ISR" => "IL", "ITA" => "IT",
    "JAM" => "JM", "JPN" => "JP", "LAT" => "LV", "NLD" => "NL",
    "NOR" => "NO", "PAK" => "PK", "POL" => "PL", "POR" => "PT",
    "PRT" => "PT", "SAF" => "ZA", "SCO" => "GB", "SUI" => "CH",
    "SVK" => "SK", "SWE" => "SE", "TGO" => "TG", "TUR" => "TR",
    "UGA" => "UG", "UKR" => "UA", "USA" => "US", "WAL" => "GB"
  }.freeze

  GENRE_KEYWORDS = {
    "folk" => %w[folk folklore traditional tradition traditionell volksmusik],
    "jazz" => %w[jazz swing improvisation],
    "blues" => %w[blues],
    "country" => %w[country bluegrass americana],
    "rock" => %w[rock punk metal],
    "pop" => %w[pop indie-pop indiepop],
    "hip-hop" => %w[hip-hop hiphop rap],
    "rap" => %w[hip-hop hiphop rap],
    "electronic" => %w[electronic electronica elektro techno],
    "dance" => %w[dance dancehall],
    "r&b" => %w[r&b soul],
    "soul" => %w[soul r&b],
    "classical" => %w[classical klassik orchestra orchester],
    "klassik" => %w[classical klassik orchestra orchester],
    "world" => %w[world weltweit weltmusik],
    "weltweit" => %w[world weltweit weltmusik],
    "traditional" => %w[traditional tradition traditionell folk]
  }.freeze

  module Text
    module_function

    def normalize(value)
      utf8 = value.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
      CGI.unescapeHTML(utf8)
        .unicode_normalize(:nfkd)
        .downcase
        .gsub(/[’‘`]/, "'")
        .gsub(/[^\p{Alnum}]+/, " ")
        .strip
        .gsub(/\s+/, " ")
    end

    def tokens(value)
      normalize(value).split.reject { |token| token.length < 2 }
    end

    def similarity(left, right)
      left_tokens = tokens(left).to_set
      right_tokens = tokens(right).to_set
      return 0.0 if left_tokens.empty? || right_tokens.empty?

      intersection = (left_tokens & right_tokens).length.to_f
      union = (left_tokens | right_tokens).length.to_f
      containment = intersection / [left_tokens.length, right_tokens.length].min
      ((intersection / union) + containment) / 2.0
    end

    def plain_html(value)
      CGI.unescapeHTML(value.to_s.gsub(/<[^>]+>/, " ")).gsub(/\s+/, " ").strip
    end

    def catalog_title(value)
      normalize(value)
        .gsub(/\b(?:single|ep|album|extended play|live|remaster(?:ed)?)\b/, " ")
        .gsub(/\s+/, " ")
        .strip
    end
  end

  module URLs
    module_function

    AppleResource = Struct.new(:kind, :id, :url, keyword_init: true)

    def apple_resource(value, storefront: "de")
      uri = URI.parse(CGI.unescapeHTML(value.to_s))
      return nil unless uri.host.to_s.downcase.end_with?("apple.com")

      match = uri.path.match(%r{/(artist|album|song)/(?:(?:[^/]+)/)?(?:id)?(\d+)(?:/|$)})
      return nil unless match

      kind = match[1]
      id = match[2]
      AppleResource.new(
        kind: kind,
        id: id,
        url: "https://music.apple.com/#{storefront.downcase}/#{kind}/#{id}"
      )
    rescue URI::InvalidURIError
      nil
    end

    def html_links(html, base_url)
      html.scan(/href\s*=\s*["']([^"']+)["']/i).filter_map do |match|
        URI.join(base_url, CGI.unescapeHTML(match.first)).to_s
      rescue URI::InvalidURIError
        nil
      end.uniq
    end

    def canonical_identity(value)
      uri = URI.parse(value.to_s)
      host = uri.host.to_s.downcase.sub(/\Awww\./, "")
      path = uri.path.to_s.downcase.sub(%r{/+\z}, "")
      [host, path]
    rescue URI::InvalidURIError
      ["", ""]
    end

    def same_identity?(left, right)
      left_host, left_path = canonical_identity(left)
      right_host, right_path = canonical_identity(right)
      return false if left_host.empty? || left_host != right_host

      social = left_host.include?("instagram.com") || left_host.include?("facebook.com")
      social ? left_path == right_path : true
    end
  end

  FestivalArtist = Struct.new(
    :id, :name, :country, :website, :facebook, :instagram, :description,
    :website_text,
    keyword_init: true
  ) do
    def country_code
      country.to_s.split(/[,;\/|]/).map(&:strip).filter_map do |code|
        COUNTRY_CODES[code]
      end.first
    end

    def identity_urls
      [website, facebook, instagram].reject { |url| url.to_s.empty? }
    end
  end

  class Candidate
    attr_reader :resource, :sources, :evidence, :albums
    attr_accessor :provider_name, :genre, :mb_name, :mb_country,
      :mb_score, :identity_match, :apple_search_rank, :score

    def initialize(resource)
      @resource = resource
      @sources = Set.new
      @evidence = []
      @albums = []
      @score = 0
    end

    def key
      [resource.kind, resource.id]
    end

    def add_source(source)
      sources << source
    end

    def add_evidence(message)
      evidence << message unless evidence.include?(message)
    end

    def merge_metadata(name: nil, genre: nil, albums: [])
      self.provider_name ||= name unless name.to_s.empty?
      self.genre ||= genre unless genre.to_s.empty?
      @albums |= albums.compact.reject(&:empty?)
    end

    def confidence
      return "verified" if score >= 90
      return "likely" if score >= 65
      return "review" if score >= 40

      "weak"
    end

    def to_h
      {
        "url" => resource.url,
        "resource_type" => resource.kind,
        "apple_id" => resource.id,
        "provider_name" => provider_name,
        "genre" => genre,
        "albums" => albums,
        "sources" => sources.to_a.sort,
        "score" => score,
        "confidence" => confidence,
        "evidence" => evidence
      }
    end
  end

  class CachedHTTPClient
    def initialize(cache_dir:, delays: {})
      @cache_dir = cache_dir
      @delays = delays
      @last_request_at = {}
      FileUtils.mkdir_p(cache_dir)
    end

    def get(uri, namespace:, accept_json: false)
      cache_path = cache_path(namespace, uri)
      return File.binread(cache_path) if File.exist?(cache_path)

      attempts = 0
      begin
        attempts += 1
        respect_delay(namespace)
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "application/json" if accept_json
        response = perform(request, uri)
        @last_request_at[namespace] = monotonic_time
        raise "HTTP #{response.code} for #{uri}" unless response.is_a?(Net::HTTPSuccess)

        File.binwrite(cache_path, response.body)
        response.body
      rescue StandardError => error
        raise if attempts >= 3

        warn "Retry #{attempts}/3: #{error.message}"
        sleep(attempts * 2)
        retry
      end
    end

    def get_json(uri, namespace:)
      JSON.parse(get(uri, namespace: namespace, accept_json: true))
    end

    private

    def perform(request, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = 10
        http.read_timeout = 20
        http.request(request)
      end
    end

    def cache_path(namespace, uri)
      directory = File.join(@cache_dir, namespace.to_s)
      FileUtils.mkdir_p(directory)
      File.join(directory, "#{Digest::SHA256.hexdigest(uri.to_s)}.cache")
    end

    def respect_delay(namespace)
      delay = @delays.fetch(namespace, 0)
      previous = @last_request_at[namespace]
      return unless previous && delay.positive?

      remaining = delay - (monotonic_time - previous)
      sleep(remaining) if remaining.positive?
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  class Scorer
    def score(candidate, artist)
      candidate.score = 0
      candidate.evidence.clear
      score_sources(candidate)
      score_provider_name(candidate, artist)
      score_musicbrainz(candidate, artist)
      score_catalog(candidate, artist)
      score_genre(candidate, artist)
      candidate.score = [[candidate.score, 0].max, 100].min
      candidate
    end

    private

    def add(candidate, points, message)
      candidate.score += points
      candidate.add_evidence("#{points.positive? ? '+' : ''}#{points}: #{message}")
    end

    def score_sources(candidate)
      if candidate.sources.include?("official_website")
        add(candidate, 60, "Apple-Link auf der Festival-Website")
      end
      if candidate.sources.include?("musicbrainz")
        add(candidate, 40, "Apple-Link in MusicBrainz")
      end
      if candidate.sources.intersect?(%w[apple_search apple_artist_search])
        add(candidate, 10, "Treffer der Apple-Suche")
      end

      case candidate.apple_search_rank
      when 1
        add(candidate, 15, "erster Treffer der Apple-Künstlersuche")
      when 2..3
        add(candidate, 10, "Top-3-Treffer der Apple-Künstlersuche")
      when 4..10
        add(candidate, 5, "Top-10-Treffer der Apple-Künstlersuche")
      end

      strong_sources = candidate.sources.count do |source|
        %w[official_website musicbrainz].include?(source)
      end
      add(candidate, 10, "mehrere unabhängige Quellen") if strong_sources >= 2
    end

    def score_provider_name(candidate, artist)
      return if candidate.provider_name.to_s.empty?

      artist_name = Text.normalize(artist.name)
      provider_name = Text.normalize(candidate.provider_name)
      if artist_name == provider_name
        add(candidate, 30, "Künstlername stimmt exakt")
        return
      end

      similarity = Text.similarity(artist.name, candidate.provider_name)
      if similarity >= 0.9
        add(candidate, 24, "Künstlername stimmt nahezu exakt")
      elsif similarity >= 0.7
        add(candidate, 14, "Künstlername ist ähnlich")
      elsif similarity >= 0.5
        add(candidate, 5, "Künstlername stimmt teilweise")
      elsif similarity < 0.3 && !corroborated_project_album?(candidate, artist)
        add(candidate, -20, "Künstlername widerspricht dem Festivalnamen")
      end
    end

    def score_musicbrainz(candidate, artist)
      return unless candidate.sources.include?("musicbrainz")

      if Text.normalize(candidate.mb_name) == Text.normalize(artist.name)
        add(candidate, 10, "MusicBrainz-Name stimmt exakt")
      end
      if artist.country_code && candidate.mb_country == artist.country_code
        add(candidate, 10, "MusicBrainz-Land stimmt")
      elsif artist.country_code && !candidate.mb_country.to_s.empty?
        add(candidate, -20, "MusicBrainz-Land widerspricht den Festivaldaten")
      end
      add(candidate, 20, "offizielle Website oder Social-ID stimmt") if candidate.identity_match
    end

    def score_catalog(candidate, artist)
      description = Text.normalize(artist.description)
      website_text = Text.normalize(artist.website_text)
      return if description.empty? && website_text.empty?

      matched_album = candidate.albums.find do |album|
        normalized = Text.catalog_title(album)
        next false if normalized.length < 5

        description.include?(normalized) &&
          (normalized != Text.normalize(artist.name) ||
            explicit_catalog_mention?(description, normalized))
      end
      add(candidate, 35, "Albumtitel aus der Festivalbeschreibung gefunden: #{matched_album}") if matched_album

      unless matched_album
        matched_keyword = catalog_keyword_match(
          candidate.albums,
          description,
          ignored_tokens: Text.tokens(artist.name).to_set
        )
        add(candidate, 20, "markanter Katalogbegriff steht in der Festivalbeschreibung: #{matched_keyword}") if matched_keyword
      end

      mentioned = credited_names_mentioned(candidate, description)
      if mentioned >= 2
        add(candidate, 35, "mehrere beteiligte Musiker stehen in der Festivalbeschreibung")
      elsif mentioned == 1 && candidate.resource.kind == "album"
        add(candidate, 10, "beteiligter Musiker steht in der Festivalbeschreibung")
      end

      title_matches_artist = candidate.resource.kind == "album" &&
        Text.catalog_title(candidate.albums.first) == Text.normalize(artist.name)
      if title_matches_artist &&
          (explicit_catalog_mention?(description, Text.normalize(artist.name)) || mentioned >= 2)
        add(candidate, 20, "gleichnamiges Album wird durch weitere Angaben bestätigt")
      end

      website_album = candidate.albums.find do |album|
        normalized = Text.catalog_title(album)
        normalized.length >= 5 && normalized != Text.normalize(artist.name) &&
          website_text.include?(normalized)
      end
      if website_album
        add(candidate, 25, "Katalogtitel steht auf der offiziellen Website: #{website_album}")
      end
    end

    def explicit_catalog_mention?(description, title)
      escaped_title = Regexp.escape(title)
      description.match?(
        /\b(?:album|ep|single|platte|veroffentlichung|programm|entitled|titled|called|heisst|namens)\b.{0,40}\b#{escaped_title}\b/
      )
    end

    def catalog_keyword_match(albums, description, ignored_tokens: Set.new)
      ignored = %w[
        album single ep live feat featuring version remix extended play
        the and with for from into only your my our der die das und mit von
      ]
      description_tokens = Text.tokens(description)
      albums.each do |album|
        title_without_credits = album.to_s.gsub(/\([^)]*\)/, " ")
        Text.tokens(title_without_credits).each do |token|
          distinctive_short_token = token.length >= 3 && !token.ascii_only?
          next if (!distinctive_short_token && token.length < 5) ||
            ignored.include?(token) || ignored_tokens.include?(token)

          return token if description_tokens.any? do |description_token|
            if distinctive_short_token
              description_token == token
            else
              description_token == token ||
                (token.length >= 5 && description_token.length >= 5 &&
                  (description_token.start_with?(token) || token.start_with?(description_token)))
            end
          end
        end
      end
      nil
    end

    def corroborated_project_album?(candidate, artist)
      return false unless candidate.resource.kind == "album"
      return false unless Text.catalog_title(candidate.albums.first) == Text.normalize(artist.name)

      credited_names_mentioned(candidate, Text.normalize(artist.description)) >= 2
    end

    def credited_names_mentioned(candidate, text)
      candidate.provider_name.to_s.split(/\s+(?:&|and|und|feat\.?)\s+|,\s*/i)
        .map { |name| Text.normalize(name) }
        .select { |name| name.length >= 5 }
        .count { |name| text.include?(name) }
    end

    def score_genre(candidate, artist)
      genre = Text.normalize(candidate.genre)
      description_tokens = Text.tokens(artist.description).to_set
      keywords = GENRE_KEYWORDS.filter_map do |genre_fragment, values|
        values if genre.include?(genre_fragment)
      end.flatten
      return if keywords.empty?

      add(candidate, 6, "Genre passt zur Festivalbeschreibung") if keywords.any? do |keyword|
        description_tokens.include?(Text.normalize(keyword))
      end
    end
  end

  class LinkFinder
    def initialize(http:, storefront:, minimum_score:)
      @http = http
      @storefront = storefront.downcase
      @minimum_score = minimum_score
      @scorer = Scorer.new
    end

    def find(artist)
      candidates = {}
      add_website_candidates(candidates, artist)
      enrich_and_score(candidates, artist)
      return result(artist, candidates) if best_score(candidates) >= 90

      add_musicbrainz_candidates(candidates, artist)
      enrich_and_score(candidates, artist)
      return result(artist, candidates) if best_score(candidates) >= 90

      add_apple_artist_search_candidates(candidates, artist)
      enrich_and_score(candidates, artist)
      return result(artist, candidates) if best_score(candidates) >= 90

      add_apple_search_candidates(candidates, artist)
      enrich_and_score(candidates, artist)
      add_description_search_candidates(candidates, artist)
      enrich_and_score(candidates, artist)
      result(artist, candidates)
    rescue StandardError => error
      warn "#{artist.name}: #{error.message}"
      {
        "festival_id" => artist.id,
        "festival_name" => artist.name,
        "country" => artist.country,
        "website" => artist.website,
        "status" => "error",
        "error" => error.message,
        "suggested_url" => nil,
        "candidates" => []
      }
    end

    private

    def add_candidate(candidates, resource, source)
      candidate = candidates[resource_key(resource)] ||= Candidate.new(resource)
      candidate.add_source(source)
      candidate
    end

    def resource_key(resource)
      [resource.kind, resource.id]
    end

    def add_website_candidates(candidates, artist)
      return if artist.website.to_s.empty?

      uri = URI.parse(artist.website)
      return unless %w[http https].include?(uri.scheme)

      html = @http.get(uri, namespace: :websites)
      artist.website_text = Text.plain_html(html)
      URLs.html_links(html, uri).each do |link|
        resource = URLs.apple_resource(link, storefront: @storefront)
        add_candidate(candidates, resource, "official_website") if resource
      end
    rescue StandardError => error
      warn "Website #{artist.name}: #{error.message}"
    end

    def add_musicbrainz_candidates(candidates, artist)
      query = %(artist:"#{artist.name.gsub('"', '\\"')}")
      query += " AND country:#{artist.country_code}" if artist.country_code
      uri = URI("https://musicbrainz.org/ws/2/artist/")
      uri.query = URI.encode_www_form(query: query, fmt: "json", limit: 5)
      search = @http.get_json(uri, namespace: :musicbrainz)
      mb_artist = select_musicbrainz_artist(search.fetch("artists", []), artist)
      return unless mb_artist

      lookup_uri = URI("https://musicbrainz.org/ws/2/artist/#{mb_artist.fetch('id')}")
      lookup_uri.query = URI.encode_www_form(inc: "url-rels", fmt: "json")
      lookup = @http.get_json(lookup_uri, namespace: :musicbrainz)
      relation_urls = lookup.fetch("relations", []).filter_map do |relation|
        relation.dig("url", "resource")
      end
      identity_match = artist.identity_urls.any? do |identity_url|
        relation_urls.any? { |relation_url| URLs.same_identity?(identity_url, relation_url) }
      end

      relation_urls.each do |url|
        resource = URLs.apple_resource(url, storefront: @storefront)
        next unless resource

        candidate = add_candidate(candidates, resource, "musicbrainz")
        candidate.mb_name = mb_artist["name"]
        candidate.mb_country = mb_artist["country"]
        candidate.mb_score = mb_artist["score"]
        candidate.identity_match = identity_match
      end
    rescue StandardError => error
      warn "MusicBrainz #{artist.name}: #{error.message}"
    end

    def select_musicbrainz_artist(candidates, artist)
      exact = candidates.select do |candidate|
        Text.normalize(candidate["name"]) == Text.normalize(artist.name)
      end
      selected = exact.max_by do |candidate|
        candidate.fetch("score", 0) + (candidate["country"] == artist.country_code ? 20 : 0)
      end
      return nil unless selected && selected.fetch("score", 0) >= 80

      selected
    end

    def add_apple_search_candidates(candidates, artist)
      search_apple_albums(candidates, artist, artist.name, attribute: "artistTerm")
    end

    def search_apple_albums(candidates, artist, term, attribute:, country: @storefront)
      uri = URI("https://itunes.apple.com/search")
      uri.query = URI.encode_www_form(
        term: term,
        media: "music",
        entity: "album",
        attribute: attribute,
        country: country.upcase,
        limit: 25
      )
      search = @http.get_json(uri, namespace: :apple)
      search.fetch("results", []).each do |item|
        next unless item["artistId"]

        artist_resource = URLs::AppleResource.new(
          kind: "artist",
          id: item["artistId"].to_s,
          url: "https://music.apple.com/#{@storefront}/artist/#{item['artistId']}"
        )
        artist_candidate = add_candidate(candidates, artist_resource, "apple_search")
        artist_candidate.merge_metadata(
          name: item["artistName"],
          genre: item["primaryGenreName"],
          albums: [item["collectionName"]]
        )

        next unless strong_album_evidence?(item, artist)

        album_resource = URLs.apple_resource(item["collectionViewUrl"], storefront: @storefront)
        next unless album_resource

        album_candidate = add_candidate(candidates, album_resource, "apple_search")
        album_candidate.merge_metadata(
          name: item["artistName"],
          genre: item["primaryGenreName"],
          albums: [item["collectionName"]]
        )
      end
    rescue StandardError => error
      warn "Apple album search #{artist.name}: #{error.message}"
    end

    def add_apple_artist_search_candidates(candidates, artist)
      uri = URI("https://itunes.apple.com/search")
      uri.query = URI.encode_www_form(
        term: artist.name,
        media: "music",
        entity: "musicArtist",
        attribute: "artistTerm",
        country: @storefront.upcase,
        limit: 25
      )
      search = @http.get_json(uri, namespace: :apple)
      search.fetch("results", []).each_with_index do |item, index|
        next unless item["artistId"]

        resource = URLs::AppleResource.new(
          kind: "artist",
          id: item["artistId"].to_s,
          url: "https://music.apple.com/#{@storefront}/artist/#{item['artistId']}"
        )
        candidate = add_candidate(candidates, resource, "apple_artist_search")
        rank = index + 1
        candidate.apple_search_rank = [candidate.apple_search_rank, rank].compact.min
        candidate.merge_metadata(
          name: item["artistName"],
          genre: item["primaryGenreName"]
        )
      end
    rescue StandardError => error
      warn "Apple artist search #{artist.name}: #{error.message}"
    end

    def add_description_search_candidates(candidates, artist)
      country = artist.country_code || @storefront
      description_search_terms(artist.description).first(2).each do |term|
        search_apple_albums(
          candidates,
          artist,
          term,
          attribute: "albumTerm",
          country: country
        )
      end
    end

    def description_search_terms(description)
      description.to_s.scan(
        /(?:entitled|titled|called|heißt|heisst|namens)\s+[„“"']?([^,.;:“”"']{4,80})/i
      ).flatten.map(&:strip).uniq
    end

    def strong_album_evidence?(item, artist)
      album = Text.catalog_title(item["collectionName"])
      description = Text.normalize(artist.description)
      return false if album.length < 5

      credited_names = item["artistName"].to_s.split(/\s+(?:&|and|und|feat\.?)\s+|,\s*/i)
        .map { |name| Text.normalize(name) }
        .select { |name| name.length >= 5 }
      multiple_credits_match = credited_names.count { |name| description.include?(name) } >= 2
      return multiple_credits_match if album == Text.normalize(artist.name)

      description.include?(album) || multiple_credits_match
    end

    def enrich_and_score(candidates, artist)
      candidates.each_value do |candidate|
        should_enrich = candidate.provider_name.to_s.empty? ||
          (candidate.resource.kind == "artist" && candidate.albums.empty? &&
            Text.similarity(artist.name, candidate.provider_name) >= 0.5)
        enrich_from_apple(candidate) if should_enrich
        @scorer.score(candidate, artist)
      end
    end

    def enrich_from_apple(candidate)
      uri = URI("https://itunes.apple.com/lookup")
      parameters = {id: candidate.resource.id, country: @storefront.upcase}
      parameters[:entity] = "album" if candidate.resource.kind == "artist"
      parameters[:limit] = 8
      uri.query = URI.encode_www_form(parameters)
      payload = @http.get_json(uri, namespace: :apple)
      items = payload.fetch("results", [])
      primary = items.find do |item|
        item["wrapperType"] == "artist" || item["wrapperType"] == "collection"
      end
      return unless primary

      albums = items.filter_map { |item| item["collectionName"] }.uniq
      candidate.merge_metadata(
        name: primary["artistName"],
        genre: primary["primaryGenreName"],
        albums: albums
      )
    end

    def best_score(candidates)
      candidates.values.map(&:score).max || 0
    end

    def result(artist, candidates)
      ranked = candidates.values.sort_by { |candidate| [-candidate.score, candidate.resource.url] }
      best = ranked.first
      accepted = best && best.score >= @minimum_score
      {
        "festival_id" => artist.id,
        "festival_name" => artist.name,
        "country" => artist.country,
        "website" => artist.website,
        "status" => best ? best.confidence : "not_found",
        "suggested_url" => accepted ? best.resource.url : nil,
        "best_candidate_url" => best&.resource&.url,
        "score" => best&.score,
        "provider_name" => best&.provider_name,
        "sources" => best&.sources&.to_a&.sort || [],
        "evidence" => best&.evidence || [],
        "candidates" => ranked.first(10).map(&:to_h)
      }
    end
  end

  class Reporter
    CSV_HEADERS = %w[
      festival_id festival_name country website status score suggested_url
      best_candidate_url provider_name sources evidence candidate_count
    ].freeze

    def self.write(results, csv_path:, json_path:)
      FileUtils.mkdir_p(File.dirname(csv_path))
      FileUtils.mkdir_p(File.dirname(json_path))
      CSV.open(csv_path, "w") do |csv|
        csv << CSV_HEADERS
        results.each do |result|
          row = result.merge("candidate_count" => result.fetch("candidates", []).length)
          csv << CSV_HEADERS.map do |header|
            value = row[header]
            value.is_a?(Array) ? value.join(" | ") : value
          end
        end
      end
      File.write(
        json_path,
        JSON.pretty_generate(
          "generated_at" => Time.now.iso8601,
          "results" => results
        )
      )
    end
  end

  class CLI
    def self.run(arguments)
      options = default_options
      parser = option_parser(options)
      parser.parse!(arguments)
      root = File.expand_path("..", __dir__)
      artists_path = File.expand_path(options[:artists], root)
      output_dir = File.expand_path(options[:output], root)
      cache_dir = File.expand_path(options[:cache], root)

      artists = load_artists(artists_path)
      unless options[:names].empty?
        requested_names = options[:names].map { |name| Text.normalize(name) }.to_set
        artists = artists.select { |artist| requested_names.include?(Text.normalize(artist.name)) }
      end
      artists = artists.first(options[:limit]) if options[:limit]
      http = CachedHTTPClient.new(
        cache_dir: cache_dir,
        delays: {musicbrainz: options[:musicbrainz_delay], apple: options[:apple_delay]}
      )
      finder = LinkFinder.new(
        http: http,
        storefront: options[:storefront],
        minimum_score: options[:minimum_score]
      )

      results = artists.each_with_index.map do |artist, index|
        puts "[#{index + 1}/#{artists.length}] #{artist.name}"
        finder.find(artist)
      end
      Reporter.write(
        results,
        csv_path: File.join(output_dir, "artist_music_links.csv"),
        json_path: File.join(output_dir, "artist_music_links.json")
      )
      print_summary(results, output_dir)
    end

    def self.default_options
      {
        artists: "Shared/PreviewData/Festival/artists.json",
        output: ".codex-tmp/artist-music-links",
        cache: ".codex-tmp/artist-music-links/cache",
        storefront: "DE",
        minimum_score: 65,
        musicbrainz_delay: 1.1,
        apple_delay: 3.1,
        limit: nil,
        names: []
      }
    end

    def self.option_parser(options)
      OptionParser.new do |parser|
        parser.banner = "Usage: ruby scripts/find_artist_music_links.rb [options]"
        parser.on("--artists PATH", "Festival artists JSON") { |value| options[:artists] = value }
        parser.on("--output PATH", "Output directory") { |value| options[:output] = value }
        parser.on("--cache PATH", "HTTP cache directory") { |value| options[:cache] = value }
        parser.on("--storefront CODE", "Apple storefront (default: DE)") { |value| options[:storefront] = value }
        parser.on("--minimum-score N", Integer, "Minimum score for suggested_url") { |value| options[:minimum_score] = value }
        parser.on("--musicbrainz-delay N", Float, "Seconds between MusicBrainz requests") { |value| options[:musicbrainz_delay] = value }
        parser.on("--apple-delay N", Float, "Seconds between Apple requests") { |value| options[:apple_delay] = value }
        parser.on("--limit N", Integer, "Only process the first N artists") { |value| options[:limit] = value }
        parser.on("--name NAME", "Only process this artist; repeatable") { |value| options[:names] << value }
        parser.on("-h", "--help", "Show help") do
          puts parser
          exit
        end
      end
    end

    def self.load_artists(path)
      JSON.parse(File.read(path)).map do |item|
        FestivalArtist.new(
          id: item["id"],
          name: CGI.unescapeHTML(item["name"].to_s),
          country: item["country"].to_s,
          website: item["website"].to_s,
          facebook: item["facebook"].to_s,
          instagram: item["instagram"].to_s,
          description: Text.plain_html(
            [item["description_de"], item["description_en"]].compact.join(" ")
          )
        )
      end
    end

    def self.print_summary(results, output_dir)
      summary = results.group_by { |result| result["status"] }.transform_values(&:length)
      puts JSON.pretty_generate(summary.sort.to_h)
      puts "Results written to #{output_dir}"
    end
  end
end

ArtistMusicLinks::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
