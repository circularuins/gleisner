const artistQuery = r'''
  query Artist($username: String!) {
    artist(username: $username) {
      id
      artistUsername
      displayName
      bio
      tagline
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
    }
  }
''';

const myArtistQuery = r'''
  query MyArtist {
    myArtist {
      id
      artistUsername
      displayName
      bio
      tagline
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
