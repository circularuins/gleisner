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
      tunedInCount
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
''';

const artistQuery =
    '''
  query Artist(\$username: String!) {
    artist(username: \$username) {
$_artistFields
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

const discoverArtistsQuery = r'''
  query DiscoverArtists($genreId: String, $query: String, $limit: Int, $offset: Int) {
    discoverArtists(genreId: $genreId, query: $query, limit: $limit, offset: $offset) {
      id
      artistUsername
      displayName
      tagline
      avatarUrl
      coverImageUrl
      tunedInCount
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
      artist {
        id
        artistUsername
        displayName
        avatarUrl
        tunedInCount
      }
    }
  }
''';

const artistRecentPostsQuery = r'''
  query ArtistRecentPosts($artistId: String!, $limit: Int) {
    artistPosts(artistId: $artistId, limit: $limit) {
      id
      mediaType
      title
      body
      createdAt
      track {
        id
        name
        color
      }
    }
  }
''';
