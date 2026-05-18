const _artistFields = '''
      id
      artistUsername
      displayName
      bio
      tagline
      location
      activeSince
      avatarUrl
      coverImageUrl
      profileVisibility
      tunedInCount
      createdAt
      activitySeries {
        date
        count
      }
      lastPostedAt
      tracks {
        id
        name
        color
        createdAt
      }
      genres {
        position
        genre {
          id
          name
        }
      }
      links {
        id
        linkCategory
        platform
        url
        position
      }
      milestones {
        id
        category
        title
        description
        date
        position
        reactionCounts {
          emoji
          count
        }
        myReactions
      }
''';

// Every post visible inside the 365-day activity window. Replaces the
// old `recentPosts(limit: 6)` field on the artist page so a single
// query feeds both the heatmap and the per-day post list under it
// (Idea 032). Same shape as `_recentPostFields` was — the consumer
// (`DayPostsSection`) renders the same cards.
const _windowedPostFields = '''
      windowedPosts {
        id
        mediaType
        title
        body
        importance
        visibility
        createdAt
        updatedAt
        author {
          id
          username
          displayName
          avatarUrl
        }
        track {
          id
          name
          color
        }
        reactionCounts {
          emoji
          count
        }
        myReactions
      }
''';

const artistQuery =
    '''
  query Artist(\$username: String!) {
    artist(username: \$username) {
$_artistFields
$_windowedPostFields
    }
  }
''';

const myArtistQuery =
    '''
  query MyArtist {
    myArtist {
$_artistFields
    }
  }
''';

// `activitySeries(days: 14)` powers the discover-card sparkline (Idea
// 032). 14 days is what the sparkline renders; clamping at the
// backend lets Phase 0 keep payloads small (<14 entries × ~30 bytes
// per artist row) without N+1ing each card. `lastPostedAt` is dropped
// because today's bar in the sparkline already conveys recency.
const discoverArtistsQuery = r'''
  query DiscoverArtists($genreId: String, $query: String, $limit: Int, $offset: Int) {
    discoverArtists(genreId: $genreId, query: $query, limit: $limit, offset: $offset) {
      id
      artistUsername
      displayName
      tagline
      avatarUrl
      coverImageUrl
      profileVisibility
      tunedInCount
      activitySeries(days: 14) {
        date
        count
      }
      genres {
        position
        genre {
          id
          name
        }
      }
    }
  }
''';

const genresQuery = r'''
  query Genres {
    genres {
      id
      name
      isPromoted
    }
  }
''';

const myTuneInsQuery = r'''
  query MyTuneIns {
    myTuneIns {
      createdAt
      lastPostActivityAt
      artist {
        id
        artistUsername
        displayName
        avatarUrl
        tunedInCount
        profileVisibility
      }
    }
  }
''';

const featuredArtistQuery = r'''
  query FeaturedArtist {
    featuredArtist {
      artistUsername
    }
  }
''';

// artistRecentPostsQuery removed — recentPosts is now a field on ArtistType (#63)
